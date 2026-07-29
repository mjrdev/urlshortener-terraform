variable "name" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "subnet_count" {
  description = "Quantidade de subnets por tier: N publicas e N privadas."
  type        = number
  default     = 3
}

variable "github_repository_terraform" {
  description = "Repo da pipeline de infraestrutura, formato owner/repo."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository_terraform))
    error_message = "Use apenas owner/repo (ex.: mjrdev/urlshortener-terraform), sem o prefixo 'repo:' nem sufixo de ref."
  }
}

variable "github_repository_terraform_id" {
  description = "Claim repository_id do repo de infraestrutura."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_terraform_id))
    error_message = "github_repository_terraform_id deve conter apenas digitos."
  }
}

variable "github_subjects_terraform" {
  description = "Refs autorizadas na role de infraestrutura."
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}

# Apenas "owner/repo" — o claim `sub` completo
# ("repo:owner/repo:<subject>") e montado em locals.tf.
variable "github_repository" {
  type = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use apenas owner/repo (ex.: mjrdev/url-shortener), sem o prefixo 'repo:' nem sufixo de ref."
  }
}

# Os IDs numericos nao vivem dentro do `sub`: sao claims proprias
# (repository_id / repository_owner_id) e sobrevivem a rename do repo.
# Obtenha com: curl -s https://api.github.com/repos/OWNER/REPO
variable "github_repository_id" {
  description = "Claim repository_id — o campo .id da API do repositorio."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id deve conter apenas digitos."
  }
}

variable "github_repository_owner_id" {
  description = "Claim repository_owner_id — o campo .owner.id da API do repositorio."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_owner_id))
    error_message = "github_repository_owner_id deve conter apenas digitos."
  }
}

variable "github_subjects" {
  description = <<-EOT
    Refs autorizadas a assumir a role, sufixo do claim `sub` do OIDC.
    Exemplos: "ref:refs/heads/main", "environment:prod", "pull_request".
  EOT
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}
