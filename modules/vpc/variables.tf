variable "name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_count" {
  description = "Quantidade de subnets por tier. O mesmo valor cria N subnets publicas e N privadas."
  type        = number
  default     = 3

  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 6
    error_message = "subnet_count deve estar entre 1 e 6."
  }
}

variable "single_nat_gateway" {
  description = "true cria um unico NAT Gateway compartilhado; false cria um por AZ (alta disponibilidade, custo maior)."
  type        = bool
  default     = true
}
