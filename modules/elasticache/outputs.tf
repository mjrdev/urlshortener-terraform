# O cliente da aplicacao monta o endereco como host:porta a partir de duas
# variaveis, entao o host sai sem a porta junto.
output "address" {
  description = "Host do primeiro no de cache, sem porta."
  value       = aws_elasticache_cluster.this.cache_nodes[0].address
}

output "port" {
  description = "Porta do cache."
  value       = aws_elasticache_cluster.this.port
}

output "arn" {
  description = "ARN do cluster — use ao escopar politicas IAM."
  value       = aws_elasticache_cluster.this.arn
}

output "cluster_id" {
  description = "Identificador do cluster."
  value       = aws_elasticache_cluster.this.cluster_id
}
