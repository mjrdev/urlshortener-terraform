output "role_arn" {
  value = module.iam_urlshortener.role_arn
}

output "ci_policy_arns" {
  value = module.iam_urlshortener.policy_arns
}

# output "vpc_id" {
#   value       = aws_vpc.url_shortener.id
#   description = "ID da VPC"
# }