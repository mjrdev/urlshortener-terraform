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

variable "app_port" {
  description = "Porta em que o container do encurtador escuta. Alvo do target group do ALB."
  type        = number
  default     = 8080
}

variable "app_health_check_path" {
  description = "Rota usada pelo ALB para checar a saude das tasks ECS."
  type        = string
  default     = "/health"
}

variable "app_image_tag" {
  description = <<-EOT
    Tag da imagem no ECR usada na primeira revisao da task definition. Os deploys
    seguintes sao feitos pela pipeline da aplicacao, que publica novas revisoes
    sem passar pelo Terraform.
  EOT
  type        = string
  default     = "latest"
}

variable "app_cpu" {
  description = "Unidades de CPU da task (1024 = 1 vCPU)."
  type        = number
  default     = 256
}

variable "app_memory" {
  description = "Memoria da task em MiB."
  type        = number
  default     = 512
}

variable "app_desired_count" {
  description = "Quantidade de tasks em regime normal, tambem o piso do autoscaling."
  type        = number
  default     = 1
}

variable "app_max_capacity" {
  description = "Teto de tasks do autoscaling."
  type        = number
  default     = 4
}

variable "terraform_repository" {
  description = "Repo da pipeline de infraestrutura, formato owner@ownerid/repo@repoid."
  type        = string
  sensitive   = true
}

variable "github_subjects_terraform" {
  description = "Refs autorizadas na role de infraestrutura."
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}

variable "app_repository" {
  description = "Repo da aplicacao, formato owner@ownerid/repo@repoid."
  type        = string
  sensitive   = true
}

variable "github_subjects" {
  description = <<-EOT
    Refs autorizadas a assumir a role, sufixo do claim `sub` do OIDC.
    Exemplos: "ref:refs/heads/main", "environment:prod", "pull_request".
  EOT
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}
