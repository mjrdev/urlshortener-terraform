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

variable "terraform_repository" {
  description = "Repo da pipeline de infraestrutura, formato owner@ownerid/repo@repoid."
  type        = string
  sensitive = true
}

variable "github_subjects_terraform" {
  description = "Refs autorizadas na role de infraestrutura."
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}

variable "app_repository" {
  description = "Repo da aplicacao, formato owner@ownerid/repo@repoid."
  type        = string
  sensitive = true
}

variable "github_subjects" {
  description = <<-EOT
    Refs autorizadas a assumir a role, sufixo do claim `sub` do OIDC.
    Exemplos: "ref:refs/heads/main", "environment:prod", "pull_request".
  EOT
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}
