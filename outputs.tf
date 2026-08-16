##########################
# Rede
##########################

output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

##########################
# ECR e IAM
##########################

output "ecr_repository_url" {
  description = "URL do repositorio ECR — destino do docker push"
  value       = module.ecr.repository_url
}

output "iam_app_role_arn" {
  description = "Role assumida pelo GitHub Actions da aplicacao"
  value       = module.iam_app.role_arn
}

output "terraform_role_arn" {
  description = "Role assumida pela pipeline de infraestrutura"
  value       = module.iam_terraform.role_arn
}

##########################
# Aplicacao
##########################

output "alb_dns_name" {
  description = "DNS publico do ALB — ponto de entrada da aplicacao"
  value       = module.alb.dns_name
}

output "alb_target_group_arn" {
  description = "Target group a ser referenciado pelo aws_ecs_service"
  value       = module.alb.target_group_arn
}

output "ecs_cluster_name" {
  description = "Cluster ECS — usado no aws ecs update-service do deploy"
  value       = module.ecs_app.cluster_name
}

output "ecs_service_name" {
  description = "Servico ECS do encurtador"
  value       = module.ecs_app.service_name
}

output "ecs_task_definition_family" {
  description = "Familia da task definition — base das revisoes publicadas pela pipeline"
  value       = module.ecs_app.task_definition_family
}

output "ecs_container_name" {
  description = "Nome do container na task definition"
  value       = module.ecs_app.container_name
}

output "ecs_log_group_name" {
  description = "Log group com a saida dos containers"
  value       = module.ecs_app.log_group_name
}

##########################
# Dados
##########################

# Nenhuma senha sai daqui: a do banco vive so no state e no parametro do SSM.

output "rds_endpoint" {
  description = "Endpoint do Postgres no formato host:porta"
  value       = module.rds.endpoint
}

output "rds_db_name" {
  description = "Nome do banco criado na instancia"
  value       = module.rds.db_name
}

output "redis_address" {
  description = "Host do cache — o que a aplicacao recebe em REDIS_URL"
  value       = module.redis.address
}
