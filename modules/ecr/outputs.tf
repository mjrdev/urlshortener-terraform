output "role_arn" {
  description = "ARN do ECR"
  value       = ecr_repo.this.arn
}