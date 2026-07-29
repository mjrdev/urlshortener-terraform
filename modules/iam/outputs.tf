output "role_arn" {
  description = "ARN da role."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Nome da role."
  value       = aws_iam_role.this.name
}

output "role_unique_id" {
  description = "ID unico da role, atribuido pela AWS."
  value       = aws_iam_role.this.unique_id
}

output "assume_role_policy" {
  description = "JSON da trust policy gerada — util para inspecionar ou testar."
  value       = data.aws_iam_policy_document.assume_role.json
}

output "policy_arns" {
  description = "ARNs das politicas criadas, por nome logico."
  value       = { for k, v in aws_iam_policy.this : k => v.arn }
}
