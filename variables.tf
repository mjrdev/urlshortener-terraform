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
  description = "Repo da pipeline de infraestrutura, formato owner@ownerid/repo@repoid."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+@[0-9]+/[A-Za-z0-9_.-]+@[0-9]+$", var.github_repository_terraform))
    error_message = "Use owner@ownerid/repo@repoid (ex.: mjrdev@52384586/urlshortener-terraform@1315325139)."
  }
}

variable "github_subjects_terraform" {
  description = "Refs autorizadas na role de infraestrutura."
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}

# Formato "owner@ownerid/repo@repoid" — e o que o GitHub coloca no claim
# `sub`. O prefixo "repo:" e o sufixo da ref sao montados em locals.tf.
# Obtenha os IDs com: curl -s https://api.github.com/repos/OWNER/REPO
variable "github_repository" {
  description = "Repo da aplicacao, formato owner@ownerid/repo@repoid."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+@[0-9]+/[A-Za-z0-9_.-]+@[0-9]+$", var.github_repository))
    error_message = "Use owner@ownerid/repo@repoid (ex.: mjrdev@52384586/url-shortener@1304417157), sem o prefixo 'repo:' nem sufixo de ref."
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
