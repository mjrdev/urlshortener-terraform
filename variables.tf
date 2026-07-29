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

# Apenas "owner/repo" — o claim `sub` completo
# ("repo:owner/repo:<subject>") e montado em locals.tf.
variable "github_repository" {
  type = string
}

variable "github_subjects" {
  description = <<-EOT
    Refs autorizadas a assumir a role, sufixo do claim `sub` do OIDC.
    Exemplos: "ref:refs/heads/main", "environment:prod", "pull_request".
  EOT
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}

variable "ecr_repository_name" {
  description = "Nome do repositorio ECR que o CI publica."
  type        = string
  default     = "url-shortener"
}