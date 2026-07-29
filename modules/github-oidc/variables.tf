variable "oidc_host" {
  description = "Host do emissor OIDC do GitHub. Só muda em GitHub Enterprise Server."
  type        = string
  default     = "token.actions.githubusercontent.com"
}
