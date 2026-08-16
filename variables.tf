##########################
# Geral
##########################

variable "name" {
  description = "Prefixo de todos os recursos do stack. Distingue os ambientes entre si."
  type        = string
}

variable "region" {
  description = "Regiao AWS do stack."
  type        = string
  default     = "us-east-1"
}

##########################
# Rede
##########################

variable "vpc_cidr" {
  description = "CIDR da VPC. Precisa comportar 2 x subnet_count faixas /24."
  type        = string
}

variable "single_nat_gateway" {
  description = <<-EOT
    Com true, um unico NAT gateway atende todas as subnets privadas: mais barato e
    ponto unico de falha. Com false, sai um NAT por AZ.
  EOT
  type        = bool
  default     = true
}

variable "subnet_count" {
  description = "Quantidade de subnets por tier: N publicas e N privadas."
  type        = number
  default     = 3
}

##########################
# Aplicacao
##########################

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

##########################
# Banco de dados
##########################

variable "db_name" {
  description = "Nome do banco criado na instancia RDS."
  type        = string
  default     = "urlshortener"
}

variable "db_username" {
  description = "Usuario master do Postgres. A senha e gerada pelo Terraform."
  type        = string
  default     = "postgres"
}

variable "db_port" {
  description = "Porta do Postgres."
  type        = number
  default     = 5432
}

variable "db_engine_version" {
  description = "Versao major do Postgres; o patch fica com a AWS."
  type        = string
  default     = "17"
}

variable "db_instance_class" {
  description = "Classe da instancia RDS. O default e a burstable mais barata."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Storage do RDS em GB (minimo 20 no gp3)."
  type        = number
  default     = 20
}

##########################
# Cache
##########################

variable "redis_node_type" {
  description = "Tipo do no do ElastiCache. O default e o menor disponivel."
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_engine_version" {
  description = "Versao da engine do cache (valkey)."
  type        = string
  default     = "8.0"
}

variable "redis_port" {
  description = "Porta do cache."
  type        = number
  default     = 6379
}

##########################
# GitHub Actions / OIDC
##########################

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
