##########################
# Segredos da aplicacao
##########################

# Senha gerada aqui, nunca digitada em tfvars. `special = false` porque a senha
# entra numa DSN (`password=...`) e caractere especial ali vira dor de cabeca de
# escape; o comprimento compensa o alfabeto menor. A AWS tambem recusa alguns
# caracteres (`/`, `@`, `"`, espaco) na senha master do RDS.
resource "random_password" "db" {
  length  = 32
  special = false
}

resource "random_password" "jwt" {
  length  = 48
  special = false
}

# Parameter Store Standard e gratuito, e com a chave gerenciada `alias/aws/ssm` a
# role de execucao das tasks precisa so de `ssm:GetParameters` — que `modules/ecs`
# ja concede sozinho a partir do input `secrets`.
module "ssm_db_password" {
  source = "./modules/ssm-parameter"

  name        = "/${var.name}/db-password"
  description = "Senha do usuario master do Postgres de ${var.name}"
  value       = random_password.db.result
}

module "ssm_jwt_secret" {
  source = "./modules/ssm-parameter"

  name        = "/${var.name}/jwt-secret"
  description = "Chave de assinatura dos tokens de ${var.name}"
  value       = random_password.jwt.result
}

##########################
# Postgres
##########################

module "sg_rds" {
  source = "./modules/security-group"

  name        = "${var.name}-rds"
  description = "Postgres do encurtador"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    tasks = {
      description                  = "Somente as tasks ECS alcancam o banco"
      referenced_security_group_id = module.sg_ecs_tasks.id
      from_port                    = var.db_port
      ip_protocol                  = "tcp"
    }
  }

  # O banco nao inicia conexao para fora; a regra existe so para nao deixar o
  # security group com egress default aberto para a internet.
  egress_rules = {
    vpc = {
      description = "Respostas dentro da VPC"
      cidr_ipv4   = module.vpc.vpc_cidr
      ip_protocol = "-1"
    }
  }
}

module "rds" {
  source = "./modules/rds"

  name    = "${var.name}-db"
  db_name = var.db_name

  # Subnets privadas e `publicly_accessible = false` no modulo: o banco so e
  # alcancavel de dentro da VPC.
  subnets            = module.vpc.private_subnet_ids
  security_group_ids = [module.sg_rds.id]

  username = var.db_username
  password = random_password.db.result
  port     = var.db_port

  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
}

##########################
# Cache
##########################

module "sg_redis" {
  source = "./modules/security-group"

  name        = "${var.name}-redis"
  description = "Cache do encurtador"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    tasks = {
      description                  = "Somente as tasks ECS alcancam o cache"
      referenced_security_group_id = module.sg_ecs_tasks.id
      from_port                    = var.redis_port
      ip_protocol                  = "tcp"
    }
  }

  egress_rules = {
    vpc = {
      description = "Respostas dentro da VPC"
      cidr_ipv4   = module.vpc.vpc_cidr
      ip_protocol = "-1"
    }
  }
}

module "redis" {
  source = "./modules/elasticache"

  name = "${var.name}-cache"

  subnets            = module.vpc.private_subnet_ids
  security_group_ids = [module.sg_redis.id]

  node_type      = var.redis_node_type
  engine_version = var.redis_engine_version
  port           = var.redis_port
}
