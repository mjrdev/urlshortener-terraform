# O cliente da aplicacao monta o endereco como host:porta a partir de duas
# variaveis, entao o host sai sem a porta junto.
output "address" {
  description = "Host do endpoint primario, sem porta."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "port" {
  description = "Porta do cache."
  value       = aws_elasticache_replication_group.this.port
}

output "arn" {
  description = "ARN do replication group — use ao escopar politicas IAM."
  value       = aws_elasticache_replication_group.this.arn
}

output "replication_group_id" {
  description = "Identificador do replication group."
  value       = aws_elasticache_replication_group.this.replication_group_id
}
