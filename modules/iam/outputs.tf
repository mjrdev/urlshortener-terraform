output "role_arn" {
  description = "ARN da role."
  value       = local.role_arn
}

output "role_name" {
  description = "Nome da role."
  value       = local.role_name
}

output "role_unique_id" {
  description = "ID unico da role, atribuido pela AWS."
  value       = local.role_unique_id
}

output "assume_role_policy" {
  description = "JSON da trust policy gerada — util para inspecionar ou testar."
  value       = data.aws_iam_policy_document.assume_role.json
}

output "policy_arns" {
  description = "ARNs das politicas criadas, por nome logico."
  value       = { for k, v in aws_iam_policy.this : k => v.arn }
}
