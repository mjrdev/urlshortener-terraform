output "repository_arn" {
  description = "ARN do repositorio — use ao escopar politicas IAM."
  value       = aws_ecr_repository.ecr_repo.arn
}

output "repository_url" {
  description = "URL do repositorio — destino do docker push."
  value       = aws_ecr_repository.ecr_repo.repository_url
}

output "repository_name" {
  description = "Nome do repositorio."
  value       = aws_ecr_repository.ecr_repo.name
}
