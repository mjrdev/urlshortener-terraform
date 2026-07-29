output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID da VPC"
}

output "ecr_repository_url" {
  value       = module.shortener-ecr.repository_url
  description = "URL do repositorio ECR — destino do docker push"
}

output "role_arn" {
  value = module.iam_urlshortener.role_arn
}

output "ci_policy_arns" {
  value = module.iam_urlshortener.policy_arns
}