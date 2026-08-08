# modules/ecs

Servico ECS em Fargate: task definition, servico, log group e as duas roles IAM.

**Cluster proprio ou compartilhado.** Sem `cluster_arn`, o modulo cria o cluster
(com capacity providers FARGATE e FARGATE_SPOT). Passando `cluster_arn`, ele apenas
acrescenta mais um servico a um cluster existente — e assim que varios servicos
dividem o mesmo cluster.

**Duas roles, dois papeis.** A role de *execucao* e do agente do ECS (puxar imagem
do ECR, escrever log, ler segredos); a role de *task* e assumida pelo container e e
nela que entram as permissoes da aplicacao, via `task_policies`. Qualquer uma pode
ser substituida por uma role existente (`execution_role_arn` / `task_role_arn`).

**Segredos.** `secrets` recebe `{ NOME_DA_VAR = "arn" }`; o valor e injetado na
partida da task e nunca aparece no state nem na task definition. A role de execucao
ganha leitura apenas nos ARNs listados.

**O servico ignora `task_definition` e `desired_count`.** O deploy da aplicacao troca
a task definition e o autoscaling mexe no numero de tasks — o Terraform nao deve
reverter nenhum dos dois no apply seguinte. Consequencia pratica: mudar
`desired_count` no tfvars depois da criacao nao tem efeito; use
`aws ecs update-service --desired-count`.

```hcl
module "ecs_app" {
  source = "./modules/ecs"

  name   = "urlshortener-ecs"
  region = "us-east-1"

  subnets            = module.vpc.private_subnet_ids
  security_group_ids = [module.sg_ecs_tasks.id]

  image          = "${module.ecr.repository_url}:latest"
  container_name = "urlshortener"
  container_port = 8080

  target_group_arn = module.alb.target_group_arn

  autoscaling = {
    min_capacity = 1
    max_capacity = 4
    cpu_target   = 70
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| image | Imagem do container, incluindo a tag (ex.: <conta>.dkr.ecr.us-east-1.amazonaws.com/app:v1). | `string` | n/a | yes |
| name | Nome do cluster, do servico e da familia da task definition. | `string` | n/a | yes |
| region | Regiao usada na configuracao do driver awslogs. | `string` | n/a | yes |
| security\_group\_ids | Security groups anexados aos ENIs das tasks. | `list(string)` | n/a | yes |
| subnets | Subnets das tasks. Use as privadas — o ALB nas publicas alcanca os ENIs pela VPC. | `list(string)` | n/a | yes |
| assign\_public\_ip | Da IP publico ao ENI da task. Necessario apenas em subnet publica sem NAT,<br/>ja que Fargate precisa de saida para a internet para puxar a imagem. | `bool` | `false` | no |
| autoscaling | Autoscaling por target tracking. Null desliga e mantem desired\_count fixo.<br/>Deixe cpu\_target ou memory\_target em null para nao criar aquela politica. | <pre>object({<br/>    min_capacity       = number<br/>    max_capacity       = number<br/>    cpu_target         = optional(number, 70)<br/>    memory_target      = optional(number, null)<br/>    scale_in_cooldown  = optional(number, 300)<br/>    scale_out_cooldown = optional(number, 60)<br/>  })</pre> | `null` | no |
| capacity\_provider\_strategy | Distribuicao entre FARGATE e FARGATE\_SPOT. Lista vazia usa launch\_type<br/>FARGATE puro. Spot custa menos, mas a task pode ser interrompida com 2<br/>minutos de aviso. | <pre>list(object({<br/>    capacity_provider = string<br/>    weight            = optional(number, 1)<br/>    base              = optional(number, 0)<br/>  }))</pre> | `[]` | no |
| cluster\_arn | Cluster ECS existente que recebe o servico. Null faz o modulo criar o<br/>cluster; informe o ARN para colocar mais de um servico no mesmo cluster. | `string` | `null` | no |
| container\_health\_check | Health check executado dentro do container. Null desliga e deixa a checagem a cargo do ALB. | <pre>object({<br/>    command      = list(string)<br/>    interval     = optional(number, 30)<br/>    timeout      = optional(number, 5)<br/>    retries      = optional(number, 3)<br/>    start_period = optional(number, 10)<br/>  })</pre> | `null` | no |
| container\_insights | Liga o Container Insights do CloudWatch no cluster. Gera custo por metrica. | `bool` | `false` | no |
| container\_name | Nome do container. Precisa bater com o container\_name do load\_balancer do servico. | `string` | `"app"` | no |
| container\_port | Porta em que o processo escuta dentro do container. | `number` | `8080` | no |
| cpu | Unidades de CPU da task (1024 = 1 vCPU). Combinacoes validas do Fargate. | `number` | `256` | no |
| cpu\_architecture | Arquitetura da task: X86\_64 ou ARM64. ARM64 exige imagem construida para arm. | `string` | `"X86_64"` | no |
| deployment\_maximum\_percent | Teto de tasks durante o deploy. 200 permite subir a nova versao antes de derrubar a antiga. | `number` | `200` | no |
| deployment\_minimum\_healthy\_percent | Percentual minimo de tasks saudaveis durante o deploy. | `number` | `100` | no |
| desired\_count | Quantidade inicial de tasks. Com autoscaling ligado o valor passa a ser gerenciado fora do Terraform. | `number` | `1` | no |
| enable\_execute\_command | Habilita `aws ecs execute-command` (shell dentro da task) e as permissoes de SSM na role da task. | `bool` | `false` | no |
| environment | Variaveis de ambiente em texto puro. Nao use para segredos — o valor fica visivel na task definition. | `map(string)` | `{}` | no |
| execution\_role\_arn | Role de execucao existente. Null faz o modulo criar uma com AmazonECSTaskExecutionRolePolicy. | `string` | `null` | no |
| health\_check\_grace\_period | Segundos que o ECS ignora o health check do ALB apos subir a task. Ignorado sem target group. | `number` | `60` | no |
| log\_retention\_in\_days | Retencao do log group das tasks. | `number` | `14` | no |
| memory | Memoria da task em MiB. Precisa ser compativel com o valor de cpu no Fargate. | `number` | `512` | no |
| secrets | Segredos injetados como variavel de ambiente, no formato<br/>{ NOME\_DA\_VAR = "arn do secret ou do parametro SSM" }. A role de execucao<br/>ganha permissao de leitura apenas nos ARNs listados. | `map(string)` | `{}` | no |
| tags | Tags adicionais aplicadas aos recursos do modulo. | `map(string)` | `{}` | no |
| target\_group\_arn | Target group do ALB que recebe as tasks. Null sobe o servico sem load balancer. | `string` | `null` | no |
| task\_policies | Policies inline da role da task, indexadas por nome. Ignorado quando task\_role\_arn e informado. | <pre>map(object({<br/>    effect    = optional(string, "Allow")<br/>    actions   = list(string)<br/>    resources = list(string)<br/>  }))</pre> | `{}` | no |
| task\_role\_arn | Role da aplicacao existente. Null faz o modulo criar uma com as policies de task\_policies. | `string` | `null` | no |
| wait\_for\_steady\_state | Faz o apply aguardar o servico estabilizar antes de concluir. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_arn | ARN do cluster ECS, criado pelo modulo ou recebido em cluster\_arn. |
| cluster\_name | Nome do cluster — usado no `aws ecs update-service` do deploy. |
| container\_name | Nome do container — exigido pelo `aws ecs deploy` e pelo mapeamento do target group. |
| execution\_role\_arn | Role de execucao usada pelas tasks. |
| log\_group\_name | Log group do CloudWatch com a saida dos containers. |
| service\_name | Nome do servico ECS. |
| task\_definition\_arn | ARN da revisao atual da task definition. |
| task\_definition\_family | Familia da task definition — base para novas revisoes publicadas pela pipeline. |
| task\_role\_arn | Role assumida pelos containers. |
<!-- END_TF_DOCS -->
