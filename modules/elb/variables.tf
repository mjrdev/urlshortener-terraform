variable "name" {
  description = "Nome do load balancer. Tambem prefixa target group e listeners."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,29}$", var.name))
    error_message = "name aceita apenas letras, numeros e hifen, com no maximo 29 caracteres (o sufixo -tg do target group ocupa o restante do limite de 32 da AWS)."
  }
}

variable "vpc_id" {
  description = "Id da VPC onde o target group e criado."
  type        = string
}

variable "subnets" {
  description = "Subnets do load balancer, ao menos duas em AZs diferentes. Publicas para ALB internet-facing."
  type        = list(string)

  validation {
    condition     = length(var.subnets) >= 2
    error_message = "Um load balancer exige subnets em pelo menos duas AZs."
  }
}

variable "security_group_ids" {
  description = "Security groups associados ao load balancer."
  type        = list(string)
}

variable "internal" {
  description = "Com true o load balancer so recebe trafego de dentro da VPC."
  type        = bool
  default     = false
}

variable "load_balancer_type" {
  description = "Tipo do load balancer: application, network ou gateway."
  type        = string
  default     = "application"

  validation {
    condition     = contains(["application", "network", "gateway"], var.load_balancer_type)
    error_message = "load_balancer_type deve ser application, network ou gateway."
  }
}

##########################
# Target group
##########################

variable "target_type" {
  description = "Tipo de alvo. Tasks ECS em modo awsvpc exigem \"ip\"."
  type        = string
  default     = "ip"

  validation {
    condition     = contains(["ip", "instance", "lambda", "alb"], var.target_type)
    error_message = "target_type deve ser ip, instance, lambda ou alb."
  }
}

variable "target_port" {
  description = "Porta em que o container escuta."
  type        = number
  default     = 80
}

variable "target_protocol" {
  description = "Protocolo usado pelo load balancer para falar com os alvos."
  type        = string
  default     = "HTTP"
}

variable "deregistration_delay" {
  description = "Segundos que o LB espera antes de remover um alvo, para drenar conexoes abertas."
  type        = number
  default     = 30
}

variable "health_check" {
  description = "Health check do target group. O alvo so recebe trafego depois de healthy_threshold respostas boas."
  type = object({
    path                = optional(string, "/")
    port                = optional(string, "traffic-port")
    matcher             = optional(string, "200")
    interval            = optional(number, 30)
    timeout             = optional(number, 5)
    healthy_threshold   = optional(number, 3)
    unhealthy_threshold = optional(number, 3)
  })
  default = {}

  validation {
    condition     = var.health_check.timeout < var.health_check.interval
    error_message = "timeout precisa ser menor que interval, senao um check ainda esta aberto quando o proximo comeca."
  }
}

##########################
# Listeners
##########################

variable "certificate_arn" {
  description = <<-EOT
    ARN do certificado ACM. Com certificado, sobe um listener HTTPS na 443 e a
    porta 80 passa a apenas redirecionar. Sem certificado, a porta 80 entrega o
    trafego direto ao target group — o trafego trafega em texto puro, entao vale
    so ate o dominio e o certificado existirem.
  EOT
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "Politica TLS do listener HTTPS. Ignorada sem certificate_arn."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

##########################
# Extras
##########################

variable "enable_deletion_protection" {
  description = "Bloqueia a exclusao do load balancer pela API."
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Segundos que uma conexao ociosa fica aberta."
  type        = number
  default     = 60
}

variable "drop_invalid_header_fields" {
  description = "Descarta headers HTTP malformados antes de repassar ao alvo."
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = <<-EOT
    Bucket S3 dos access logs. O bucket precisa existir antes e ter policy
    permitindo escrita pelo servico de log da AWS — o modulo nao cria nenhum dos
    dois. Deixe null para nao habilitar.
  EOT
  type        = string
  default     = null
}

variable "access_logs_prefix" {
  description = "Prefixo das chaves dos access logs dentro do bucket."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags adicionais aplicadas no load balancer, target group e listeners."
  type        = map(string)
  default     = {}
}
