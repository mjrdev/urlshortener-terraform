variable "name" {
  description = "Nome (caminho) do parametro, ex: /urlshortener/db-password."
  type        = string
}

variable "value" {
  description = "Valor do parametro. Vai para o state — use um backend privado."
  type        = string
  sensitive   = true
}

variable "type" {
  description = "String, StringList ou SecureString."
  type        = string
  default     = "SecureString"

  validation {
    condition     = contains(["String", "StringList", "SecureString"], var.type)
    error_message = "type deve ser String, StringList ou SecureString."
  }
}

variable "description" {
  description = "Descricao do parametro."
  type        = string
  default     = null
}

variable "key_id" {
  description = <<-EOT
    Chave KMS usada quando type e SecureString. Nulo usa a chave gerenciada
    `alias/aws/ssm`, que dispensa `kms:Decrypt` na role de execucao das tasks.
  EOT
  type        = string
  default     = null
}

variable "tier" {
  description = "Standard e gratuito e cobre valores de ate 4 KB."
  type        = string
  default     = "Standard"
}

variable "tags" {
  description = "Tags adicionais aplicadas ao parametro."
  type        = map(string)
  default     = {}
}
