variable "name" {
  description = "Nome da role. Tambem prefixa o nome das politicas criadas."
  type        = string
}

variable "description" {
  description = "Descricao da role."
  type        = string
  default     = null
}

variable "path" {
  description = "Path IAM da role."
  type        = string
  default     = "/"
}

variable "max_session_duration" {
  description = "Duracao maxima da sessao, em segundos (3600 a 43200)."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration deve estar entre 3600 e 43200."
  }
}

variable "trust_statements" {
  description = <<-EOT
    Statements da trust policy (quem pode assumir a role). Generico: serve para
    service principals, cross-account, OIDC ou SAML.

    Exemplo de service principal:
      [{ principals = [{ type = "Service", identifiers = ["ec2.amazonaws.com"] }] }]

    Exemplo federado com condicoes:
      [{
        actions    = ["sts:AssumeRoleWithWebIdentity"]
        principals = [{ type = "Federated", identifiers = [provider_arn] }]
        conditions = [{ test = "StringLike", variable = "...:sub", values = ["..."] }]
      }]
  EOT
  type = list(object({
    effect  = optional(string, "Allow")
    actions = optional(list(string), ["sts:AssumeRole"])
    principals = list(object({
      type        = string
      identifiers = list(string)
    }))
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))

  validation {
    condition     = length(var.trust_statements) > 0
    error_message = "trust_statements precisa de ao menos um statement, senao ninguem assume a role."
  }

  validation {
    condition = alltrue([
      for s in var.trust_statements : alltrue([
        for p in s.principals : contains(["Service", "AWS", "Federated", "CanonicalUser", "*"], p.type)
      ])
    ])
    error_message = "principals.type deve ser Service, AWS, Federated, CanonicalUser ou *."
  }
}

variable "policies" {
  description = <<-EOT
    Politicas gerenciadas pelo modulo, indexadas por nome logico.
    A chave do mapa compoe o nome final da politica e a identidade dela no state.
  EOT
  type = map(object({
    actions   = list(string)
    resources = optional(list(string), ["*"])
    effect    = optional(string, "Allow")
  }))
  default = {}

  validation {
    condition     = alltrue([for p in var.policies : contains(["Allow", "Deny"], p.effect)])
    error_message = "effect deve ser Allow ou Deny."
  }

  validation {
    condition     = alltrue([for p in var.policies : length(p.actions) > 0])
    error_message = "Cada politica precisa de ao menos uma action."
  }
}

variable "managed_policy_arns" {
  description = "ARNs de politicas gerenciadas pela AWS a anexar na role."
  type        = list(string)
  default     = []
}

variable "prevent_destroy" {
  description = <<-EOT
    Trava a role contra destroy. Com true, qualquer plano que remova a role —
    inclusive `terraform destroy` do stack inteiro — falha ainda no plan.

    Para realmente deletar depois, mude para false, aplique, e so entao remova
    o modulo. Alternar o valor recria a role: a que sai e a que entra sao
    recursos diferentes no state, entao o destroy da antiga tambem esbarra na
    trava. Trocar exige `terraform state mv` entre aws_iam_role.protected[0] e
    aws_iam_role.this[0].
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags adicionais aplicadas na role e nas politicas."
  type        = map(string)
  default     = {}
}
