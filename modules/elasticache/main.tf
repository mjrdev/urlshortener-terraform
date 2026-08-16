resource "aws_elasticache_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnets

  tags = merge({ Name = var.name }, var.tags)
}

# `aws_elasticache_cluster`, e nao `aws_elasticache_replication_group`: sem replica
# e sem failover, este e o recurso mais simples que entrega o cache mais barato. Um
# no so, sem TLS e sem auth token — o isolamento vem da rede (subnets privadas e
# security group com origem unica), nao de senha.
resource "aws_elasticache_cluster" "this" {
  cluster_id = var.name

  engine          = var.engine
  engine_version  = var.engine_version
  node_type       = var.node_type
  num_cache_nodes = var.num_cache_nodes
  port            = var.port

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  parameter_group_name = var.parameter_group_name
  maintenance_window   = var.maintenance_window
  apply_immediately    = var.apply_immediately

  tags = merge({ Name = var.name }, var.tags)
}
