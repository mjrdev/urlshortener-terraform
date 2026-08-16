resource "aws_elasticache_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnets

  tags = merge({ Name = var.name }, var.tags)
}

# Replication group com um no so, e nao `aws_elasticache_cluster`: o recurso de
# cluster aceita apenas `memcached` e `redis`, e Valkey — que fala o mesmo
# protocolo — custa cerca de 20% menos por no. Com `num_cache_clusters = 1` nao ha
# replica nem failover; o grupo existe so como embalagem da engine.
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = coalesce(var.description, "Cache de ${var.name}")

  engine         = var.engine
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port

  num_cache_clusters = var.num_cache_nodes
  # Failover exige mais de um no; com um so, ligar isso quebra o apply.
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled           = var.num_cache_nodes > 1 && var.multi_az

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  # Sem TLS e sem auth token: o isolamento vem da rede, e o cliente conecta com
  # host e porta apenas. Ligar transit encryption exigiria REDIS_TLS=true no app.
  transit_encryption_enabled = var.transit_encryption_enabled

  parameter_group_name = var.parameter_group_name
  maintenance_window   = var.maintenance_window
  apply_immediately    = var.apply_immediately

  tags = merge({ Name = var.name }, var.tags)
}
