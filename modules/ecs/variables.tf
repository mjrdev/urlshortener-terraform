variable "name" {
  description = "Nome do cluster, do servico e da familia da task definition."
  type        = string
}

variable "region" {
  description = "Regiao usada na configuracao do driver awslogs."
  type        = string
}

variable "cluster_arn" {
  description = <<-EOT
    Cluster ECS existente que recebe o servico. Null faz o modulo criar o
    cluster; informe o ARN para colocar mais de um servico no mesmo cluster.
  EOT
  type        = string
  default     = null
}

##########################
# Rede
##########################

variable "subnets" {
  description = "Subnets das tasks. Use as privadas — o ALB nas publicas alcanca os ENIs pela VPC."
  type        = list(string)

  validation {
    condition     = length(var.subnets) > 0
    error_message = "Informe ao menos uma subnet para as tasks."
  }
}

variable "security_group_ids" {
  description = "Security groups anexados aos ENIs das tasks."
  type        = list(string)
}

variable "assign_public_ip" {
  description = <<-EOT
    Da IP publico ao ENI da task. Necessario apenas em subnet publica sem NAT,
    ja que Fargate precisa de saida para a internet para puxar a imagem.
  EOT
  type        = bool
  default     = false
}

##########################
# Container
##########################

variable "image" {
  description = "Imagem do container, incluindo a tag (ex.: <conta>.dkr.ecr.us-east-1.amazonaws.com/app:v1)."
  type        = string
}

variable "container_name" {
  description = "Nome do container. Precisa bater com o container_name do load_balancer do servico."
  type        = string
  default     = "app"
}

variable "container_port" {
  description = "Porta em que o processo escuta dentro do container."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Unidades de CPU da task (1024 = 1 vCPU). Combinacoes validas do Fargate."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memoria da task em MiB. Precisa ser compativel com o valor de cpu no Fargate."
  type        = number
  default     = 512
}

variable "cpu_architecture" {
  description = "Arquitetura da task: X86_64 ou ARM64. ARM64 exige imagem construida para arm."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture deve ser X86_64 ou ARM64."
  }
}

variable "environment" {
  description = "Variaveis de ambiente em texto puro. Nao use para segredos — o valor fica visivel na task definition."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = <<-EOT
    Segredos injetados como variavel de ambiente, no formato
    { NOME_DA_VAR = "arn do secret ou do parametro SSM" }. A role de execucao
    ganha permissao de leitura apenas nos ARNs listados.
  EOT
  type        = map(string)
  default     = {}
}

variable "container_health_check" {
  description = "Health check executado dentro do container. Null desliga e deixa a checagem a cargo do ALB."
  type = object({
    command      = list(string)
    interval     = optional(number, 30)
    timeout      = optional(number, 5)
    retries      = optional(number, 3)
    start_period = optional(number, 10)
  })
  default = null
}

##########################
# Servico
##########################

variable "desired_count" {
  description = "Quantidade inicial de tasks. Com autoscaling ligado o valor passa a ser gerenciado fora do Terraform."
  type        = number
  default     = 1
}

variable "target_group_arn" {
  description = "Target group do ALB que recebe as tasks. Null sobe o servico sem load balancer."
  type        = string
  default     = null
}

variable "health_check_grace_period" {
  description = "Segundos que o ECS ignora o health check do ALB apos subir a task. Ignorado sem target group."
  type        = number
  default     = 60
}

variable "deployment_minimum_healthy_percent" {
  description = "Percentual minimo de tasks saudaveis durante o deploy."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Teto de tasks durante o deploy. 200 permite subir a nova versao antes de derrubar a antiga."
  type        = number
  default     = 200
}

variable "capacity_provider_strategy" {
  description = <<-EOT
    Distribuicao entre FARGATE e FARGATE_SPOT. Lista vazia usa launch_type
    FARGATE puro. Spot custa menos, mas a task pode ser interrompida com 2
    minutos de aviso.
  EOT
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 1)
    base              = optional(number, 0)
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.capacity_provider_strategy : contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)
    ])
    error_message = "capacity_provider deve ser FARGATE ou FARGATE_SPOT."
  }
}

variable "enable_execute_command" {
  description = "Habilita `aws ecs execute-command` (shell dentro da task) e as permissoes de SSM na role da task."
  type        = bool
  default     = false
}

variable "wait_for_steady_state" {
  description = "Faz o apply aguardar o servico estabilizar antes de concluir."
  type        = bool
  default     = false
}

##########################
# IAM
##########################

variable "execution_role_arn" {
  description = "Role de execucao existente. Null faz o modulo criar uma com AmazonECSTaskExecutionRolePolicy."
  type        = string
  default     = null
}

variable "task_role_arn" {
  description = "Role da aplicacao existente. Null faz o modulo criar uma com as policies de task_policies."
  type        = string
  default     = null
}

variable "task_policies" {
  description = "Policies inline da role da task, indexadas por nome. Ignorado quando task_role_arn e informado."
  type = map(object({
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
  }))
  default = {}
}

##########################
# Observabilidade e escala
##########################

variable "container_insights" {
  description = "Liga o Container Insights do CloudWatch no cluster. Gera custo por metrica."
  type        = bool
  default     = false
}

variable "log_retention_in_days" {
  description = "Retencao do log group das tasks."
  type        = number
  default     = 14
}

variable "autoscaling" {
  description = <<-EOT
    Autoscaling por target tracking. Null desliga e mantem desired_count fixo.
    Deixe cpu_target ou memory_target em null para nao criar aquela politica.
  EOT
  type = object({
    min_capacity       = number
    max_capacity       = number
    cpu_target         = optional(number, 70)
    memory_target      = optional(number, null)
    scale_in_cooldown  = optional(number, 300)
    scale_out_cooldown = optional(number, 60)
  })
  default = null

  validation {
    condition     = var.autoscaling == null || try(var.autoscaling.min_capacity <= var.autoscaling.max_capacity, false)
    error_message = "min_capacity precisa ser menor ou igual a max_capacity."
  }
}

variable "tags" {
  description = "Tags adicionais aplicadas aos recursos do modulo."
  type        = map(string)
  default     = {}
}
