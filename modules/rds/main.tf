resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnets

  tags = merge({ Name = var.name }, var.tags)
}

resource "aws_db_instance" "this" {
  identifier = var.name

  engine = var.engine
  # So o major: com `auto_minor_version_upgrade` o patch fica com a AWS e nao vira
  # diff no plan a cada release.
  engine_version             = var.engine_version
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  max_allocated_storage = (
    var.max_allocated_storage == null ? null : max(var.max_allocated_storage, var.allocated_storage)
  )
  storage_type      = var.storage_type
  storage_encrypted = var.storage_encrypted

  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  # Banco em subnet privada: sem endereco publico, o acesso e so de dentro da VPC.
  publicly_accessible = false

  multi_az                     = var.multi_az
  backup_retention_period      = var.backup_retention_period
  backup_window                = var.backup_window
  maintenance_window           = var.maintenance_window
  performance_insights_enabled = var.performance_insights_enabled

  # Ambiente descartavel (ADR-0013): o destroy nao pode parar pedindo nome de
  # snapshot nem exigir desligar protecao antes.
  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection
  apply_immediately   = var.apply_immediately

  tags = merge({ Name = var.name }, var.tags)
}
