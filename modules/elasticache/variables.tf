variable "name" {
  description = "Nome do cluster e do subnet group."
  type        = string
}

variable "description" {
  description = "Descricao do replication group. Nulo gera uma a partir de `name`."
  type        = string
  default     = null
}

variable "subnets" {
  description = "Subnets do subnet group — use as privadas."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups do cluster."
  type        = list(string)
}

variable "engine" {
  description = "valkey ou redis. Valkey fala o mesmo protocolo e custa igual ou menos."
  type        = string
  default     = "valkey"

  validation {
    condition     = contains(["valkey", "redis"], var.engine)
    error_message = "engine deve ser valkey ou redis."
  }
}

variable "engine_version" {
  description = "Versao da engine."
  type        = string
  default     = "8.0"
}

variable "node_type" {
  description = "Tipo do no. O default e o menor disponivel."
  type        = string
  default     = "cache.t4g.micro"
}

variable "num_cache_nodes" {
  description = <<-EOT
    Quantidade de nos do grupo. Com 1 nao ha replica nem failover — o mais barato.
    Acima de 1 o failover automatico e ligado sozinho.
  EOT
  type        = number
  default     = 1
}

variable "multi_az" {
  description = "Distribui os nos entre AZs. So vale com mais de um no."
  type        = bool
  default     = false
}

variable "transit_encryption_enabled" {
  description = "TLS na conexao. Ligado exige cliente com TLS (REDIS_TLS=true no app)."
  type        = bool
  default     = false
}

variable "port" {
  description = "Porta do cache."
  type        = number
  default     = 6379
}

variable "parameter_group_name" {
  description = "Parameter group. Nulo usa o default da familia da engine."
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "Janela de manutencao, formato ddd:hh24:mi-ddd:hh24:mi em UTC."
  type        = string
  default     = null
}

variable "apply_immediately" {
  description = "Aplica a mudanca na hora em vez de esperar a janela de manutencao."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionais aplicadas ao cluster e ao subnet group."
  type        = map(string)
  default     = {}
}
