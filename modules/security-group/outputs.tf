output "id" {
  description = "Id do security group."
  value       = aws_security_group.this.id
}

output "arn" {
  description = "ARN do security group."
  value       = aws_security_group.this.arn
}

output "name" {
  description = "Nome do security group."
  value       = aws_security_group.this.name
}

output "ingress_rule_ids" {
  description = "Ids das regras de entrada, por nome logico."
  value       = { for k, v in aws_vpc_security_group_ingress_rule.this : k => v.security_group_rule_id }
}

output "egress_rule_ids" {
  description = "Ids das regras de saida, por nome logico."
  value       = { for k, v in aws_vpc_security_group_egress_rule.this : k => v.security_group_rule_id }
}
