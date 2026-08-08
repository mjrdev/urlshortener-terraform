output "cluster_arn" {
  description = "ARN do cluster ECS, criado pelo modulo ou recebido em cluster_arn."
  value       = local.cluster_arn
}

output "cluster_name" {
  description = "Nome do cluster — usado no `aws ecs update-service` do deploy."
  value       = local.cluster_name
}

output "service_name" {
  description = "Nome do servico ECS."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN da revisao atual da task definition."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Familia da task definition — base para novas revisoes publicadas pela pipeline."
  value       = aws_ecs_task_definition.this.family
}

output "execution_role_arn" {
  description = "Role de execucao usada pelas tasks."
  value       = local.execution_role_arn
}

output "task_role_arn" {
  description = "Role assumida pelos containers."
  value       = local.task_role_arn
}

output "log_group_name" {
  description = "Log group do CloudWatch com a saida dos containers."
  value       = aws_cloudwatch_log_group.this.name
}

output "container_name" {
  description = "Nome do container — exigido pelo `aws ecs deploy` e pelo mapeamento do target group."
  value       = var.container_name
}
