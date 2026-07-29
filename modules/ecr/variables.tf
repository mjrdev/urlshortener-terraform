variable "name" {
  type = string
}

variable "readonly" {
  description = "Se true, o repositório nao permite alteracoes."
  default     = false
}