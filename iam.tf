# O id da conta entra nos ARNs das politicas por data source, nunca literal: este
# repositorio e publico e o numero da conta nao precisa aparecer nele.
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Prefixo dos recursos IAM que esta pipeline tem permissao de gerenciar. Todo
  # recurso nasce de `var.name` (ver Convencoes no CLAUDE.md), entao o prefixo
  # cobre as roles dos modulos — inclusive as que `modules/ecs` cria sozinho
  # (`<name>-execution`, `<name>-task`).
  iam_scope = "arn:aws:iam::${local.account_id}:role/${var.name}*"

  # Um trust statement por repositorio autorizado. Indexado por apelido
  # para nao duplicar o bloco a cada repo novo.
  github_repos = {
    app = {
      repository = var.app_repository
      subjects   = var.github_subjects
    }
    terraform = {
      repository = var.terraform_repository
      subjects   = var.github_subjects_terraform
    }
  }

  github_actions_trust = {
    for key, repo in local.github_repos : key => [{
      actions    = ["sts:AssumeRoleWithWebIdentity"]
      principals = [{ type = "Federated", identifiers = [module.github_oidc.arn] }]

      # O `sub` ja carrega owner@ownerid/repo@repoid, entao os IDs numericos
      # protegem contra rename sem precisar de condicoes separadas.
      conditions = [
        {
          test     = "StringEquals"
          variable = "${module.github_oidc.host}:aud"
          values   = ["sts.amazonaws.com"]
        },
        {
          test     = "StringLike"
          variable = "${module.github_oidc.host}:sub"
          values   = [for s in repo.subjects : "repo:${repo.repository}:${s}"]
        },
      ]
    }]
  }
}

module "github_oidc" {
  source = "./modules/github-oidc"

  prevent_destroy = true
}

module "iam_app" {
  source = "./modules/iam"

  name        = "${var.name}-github-actions"
  description = "Role assumida pelo GitHub Actions de ${var.app_repository}"

  trust_statements = local.github_actions_trust["app"]

  policies = {
    ecr-auth = {
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }

    ecr-push = {
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:ListImages",
      ]
      resources = [module.ecr.repository_arn]
    }
  }
}

module "iam_terraform" {
  source = "./modules/iam"

  name        = "${var.name}-terraform-github-actions"
  description = "Role da pipeline de infraestrutura (${var.terraform_repository})"

  trust_statements = local.github_actions_trust["terraform"]

  # Substitui o `AdministratorAccess` que esta role tinha. O ganho nao e cosmetico:
  # e o unico controle desta infra que alguem com o repositorio na mao **nao
  # consegue desfazer** — ruleset, environment e required reviewer sao todos
  # reversiveis por quem tem admin no repo, a politica IAM nao.
  #
  # O criterio das listas e "so as acoes que os modulos em modules/ realmente
  # chamam". Servico novo => acao nova aqui, senao o apply para com AccessDenied.
  # Ausencias deliberadas: `ec2:RunInstances`, `ec2:CreateVolume` e afins (bloqueia
  # o uso classico de conta comprometida para mineracao), `iam:*User*`,
  # `iam:CreateAccessKey` (bloqueia persistencia) e `s3:DeleteBucket` (o state).
  #
  # Lembrar de duas armadilhas ao acrescentar acao:
  # 1. Operacao de listagem (`List*`, e `logs:DescribeLogGroups`) nao aceita
  #    resource-level: a AWS avalia contra um recurso generico, entao numa entrada
  #    escopada por ARN ela nunca autoriza. Ou vai para uma entrada com `"*"`, ou
  #    o ARN generico entra na lista de resources (ver `logs`).
  # 2. O destroy chama APIs que o apply nunca chamou — `ec2:DisassociateAddress`
  #    (EIP do NAT) e o exemplo. Validar as duas direcoes antes de fechar.
  #
  # Limite da AWS: 10 politicas gerenciadas por role. Hoje sao 10 — o teto. Acao
  # nova entra numa entrada existente; entrada nova exige juntar duas ou pedir
  # aumento de quota.
  policies = {
    # ARNs de rede sao atribuidos na criacao, entao a maioria das acoes de EC2 nao
    # aceita resource-level: o escopo aqui vem da lista de acoes, nao do recurso.
    network = {
      actions = [
        "ec2:Describe*",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        # O EIP do NAT gateway: o provider desassocia antes de liberar, entao sem
        # estas duas o destroy para depois de ja ter apagado a VPC.
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ReplaceRoute",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:ModifySecurityGroupRules",
        "ec2:CreateTags",
        "ec2:DeleteTags",
      ]
      resources = ["*"]
    }

    ecr = {
      actions = [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:ListTagsForResource",
        "ecr:TagResource",
        "ecr:UntagResource",
        "ecr:PutLifecyclePolicy",
        "ecr:GetLifecyclePolicy",
        "ecr:DeleteLifecyclePolicy",
        "ecr:PutImageScanningConfiguration",
        "ecr:PutImageTagMutability",
        "ecr:SetRepositoryPolicy",
        "ecr:GetRepositoryPolicy",
        "ecr:DeleteRepositoryPolicy",
      ]
      resources = ["arn:aws:ecr:*:${local.account_id}:repository/${var.name}*"]
    }

    ecs = {
      actions = [
        "ecs:CreateCluster",
        "ecs:DeleteCluster",
        "ecs:DescribeClusters",
        "ecs:PutClusterCapacityProviders",
        "ecs:CreateService",
        "ecs:UpdateService",
        "ecs:DeleteService",
        "ecs:DescribeServices",
        "ecs:RegisterTaskDefinition",
        "ecs:DeregisterTaskDefinition",
        "ecs:DescribeTaskDefinition",
        "ecs:ListTaskDefinitions",
        "ecs:ListClusters",
        "ecs:ListServices",
        "ecs:TagResource",
        "ecs:UntagResource",
        "ecs:ListTagsForResource",
      ]
      resources = ["*"]
    }

    elb = {
      actions = [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
      ]
      resources = ["*"]
    }

    logs = {
      actions = [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:DeleteRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource",
        "logs:ListTagsForResource",
      ]
      resources = [
        "arn:aws:logs:*:${local.account_id}:log-group:/ecs/${var.name}*",

        # `logs:DescribeLogGroups` e uma operacao de listagem: a AWS a avalia contra
        # este pseudo-ARN de log-group vazio, nunca contra o grupo que o filtro
        # devolve. Sem ele o `terraform plan` para com AccessDenied so ao **ler** o
        # log group do ECS. Nao afrouxa as demais acoes: nenhum log group real casa
        # com este ARN, entao Create/Delete continuam presos ao prefixo /ecs/<name>.
        "arn:aws:logs:*:${local.account_id}:log-group::log-stream:",
      ]
    }

    autoscaling = {
      actions = [
        "application-autoscaling:RegisterScalableTarget",
        "application-autoscaling:DeregisterScalableTarget",
        "application-autoscaling:DescribeScalableTargets",
        "application-autoscaling:PutScalingPolicy",
        "application-autoscaling:DeleteScalingPolicy",
        "application-autoscaling:DescribeScalingPolicies",
        "application-autoscaling:ListTagsForResource",
        "application-autoscaling:TagResource",
      ]
      resources = ["*"]
    }

    # Politica separada de proposito: `modules/iam` gera um statement por entrada do
    # mapa, entao juntar esta acao com as de autoscaling — que precisam de `"*"` —
    # aplicaria `"*"` aqui tambem e o escopo no path viraria enfeite. E o path e todo
    # o ponto: ECS, ELB e o autoscaling criam a service-linked role deles na primeira
    # execucao, sem que isso vire um `iam:CreateRole` generico.
    service-linked-roles = {
      actions   = ["iam:CreateServiceLinkedRole"]
      resources = ["arn:aws:iam::${local.account_id}:role/aws-service-role/*"]
    }

    # Escopo no prefixo do projeto: a pipeline mexe nas roles que ela mesma cria e
    # em nenhuma outra da conta. `iam:PassRole` e obrigatorio para registrar a task
    # definition com as roles de execucao e de task.
    iam-project = {
      actions = [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:UpdateRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:PassRole",
      ]
      resources = [local.iam_scope]
    }

    # As politicas gerenciadas que `modules/iam` cria, e o provider OIDC.
    iam-policies = {
      actions = [
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:TagPolicy",
        "iam:UntagPolicy",
        "iam:ListEntitiesForPolicy",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:TagOpenIDConnectProvider",
      ]
      resources = [
        "arn:aws:iam::${local.account_id}:policy/${var.name}*",
        "arn:aws:iam::${local.account_id}:oidc-provider/*",
      ]
    }

    # Backend S3. Sem `s3:DeleteBucket`: um apply nao deve poder apagar o proprio
    # historico de state.
    state = {
      actions = [
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      resources = [
        "arn:aws:s3:::mjr-terraform",
        "arn:aws:s3:::mjr-terraform/url-shortener/*",
      ]
    }
  }

  prevent_destroy = true
}
