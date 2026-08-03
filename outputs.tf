output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID da VPC"
}

output "ecr_repository_url" {
  value       = module.shortener-ecr.repository_url
  description = "URL do repositorio ECR — destino do docker push"
}

output "iam_urlshortener_role_arn" {
  value = module.iam_urlshortener.role_arn
}

output "terraform_role_arn" {
  value = module.iam_terraform.role_arn
}

output "alb_dns_name" {
  value       = module.alb_ecs.dns_name
  description = "DNS publico do ALB — ponto de entrada da aplicacao"
}

output "alb_target_group_arn" {
  value       = module.alb_ecs.target_group_arn
  description = "Target group a ser referenciado pelo aws_ecs_service"
}

output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "Cluster ECS — usado no aws ecs update-service do deploy"
}

output "ecs_service_name" {
  value       = module.ecs.service_name
  description = "Servico ECS do encurtador"
}

output "ecs_task_definition_family" {
  value       = module.ecs.task_definition_family
  description = "Familia da task definition — base das revisoes publicadas pela pipeline"
}

output "ecs_container_name" {
  value       = module.ecs.container_name
  description = "Nome do container na task definition"
}

output "ecs_log_group_name" {
  value       = module.ecs.log_group_name
  description = "Log group com a saida dos containers"
}