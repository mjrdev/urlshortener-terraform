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