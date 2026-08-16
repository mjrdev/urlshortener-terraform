variable "name" {
  description = "Nome do identificador da instancia e do subnet group."
  type        = string
}

variable "subnets" {
  description = "Subnets do subnet group — use as privadas."
  type        = list(string)

  validation {
    condition     = length(var.subnets) >= 2
    error_message = "A AWS exige subnets em pelo menos duas AZs no subnet group."
  }
}

variable "security_group_ids" {
  description = "Security groups da instancia."
  type        = list(string)
}

variable "db_name" {
  description = "Nome do banco criado na instancia."
  type        = string
}

variable "username" {
  description = "Usuario master."
  type        = string
  default     = "postgres"
}

variable "password" {
  description = "Senha do usuario master. Vai para o state — gere com random_password."
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Porta do banco."
  type        = number
  default     = 5432
}

variable "engine" {
  description = "Engine do RDS."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Versao da engine. So o major deixa o patch com a AWS."
  type        = string
  default     = "17"
}

variable "auto_minor_version_upgrade" {
  description = "Aplica patches de versao menor na janela de manutencao."
  type        = bool
  default     = true
}

variable "instance_class" {
  description = "Classe da instancia. O default e a burstable mais barata."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage inicial em GB (minimo 20 no gp3)."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = <<-EOT
    Teto do autoscaling de storage em GB. Nulo desliga o autoscaling — o storage
    fica fixo em `allocated_storage` e o custo fica previsivel.
  EOT
  type        = number
  default     = null
}

variable "storage_type" {
  description = "Tipo do volume."
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Criptografia em repouso. Nao custa nada com a chave gerenciada."
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Standby em outra AZ. Dobra o custo da instancia."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Dias de retencao do backup automatico. Zero desliga o backup."
  type        = number
  default     = 1
}

variable "backup_window" {
  description = "Janela do backup automatico, formato hh24:mi-hh24:mi em UTC."
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "Janela de manutencao, formato ddd:hh24:mi-ddd:hh24:mi em UTC."
  type        = string
  default     = null
}

variable "performance_insights_enabled" {
  description = "Performance Insights. Desligado por ser pago fora do periodo gratuito."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Dispensa o snapshot final no destroy."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Trava a instancia contra destroy — exige um apply para desligar."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Aplica a mudanca na hora em vez de esperar a janela de manutencao."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionais aplicadas a instancia e ao subnet group."
  type        = map(string)
  default     = {}
}
