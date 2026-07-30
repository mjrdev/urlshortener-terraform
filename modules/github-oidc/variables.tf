variable "oidc_host" {
  description = "Host do emissor OIDC do GitHub. Só muda em GitHub Enterprise Server."
  type        = string
  default     = "token.actions.githubusercontent.com"
}

variable "prevent_destroy" {
  description = <<-EOT
    Trava o provider OIDC contra destroy. Com true, qualquer plano que o remova
    — inclusive `terraform destroy` do stack inteiro — falha ainda no plan.
    Destruir o provider invalidaria a trust policy de todas as roles do GitHub
    Actions de uma vez, entao a trava e a protecao mais ampla do stack.

    Para deletar de verdade depois, mude para false, aplique, e so entao remova
    o modulo.
  EOT
  type        = bool
  default     = false
}
