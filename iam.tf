locals {
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

  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]

  prevent_destroy = true
}
