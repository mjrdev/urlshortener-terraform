##########################
# Entrada: ALB publico
##########################

module "sg_alb" {
  source = "./modules/security-group"

  name        = "${var.name}-alb-ecs"
  description = "ALB cluster ecs"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    http = {
      # Sem certificate_arn no modulo elb, o listener 80 entrega direto ao target
      # group; o redirect para 443 so passa a valer quando houver certificado.
      description = "HTTP publico"
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 80
      ip_protocol = "tcp"
    }

    https = {
      description = "HTTPS publico"
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 443
      ip_protocol = "tcp"
    }
  }

  egress_rules = {
    targets = {
      description = "Alcanca as tasks ECS dentro da VPC"
      cidr_ipv4   = module.vpc.vpc_cidr
      ip_protocol = "-1"
    }
  }
}

module "alb" {
  source = "./modules/elb"

  name   = "${var.name}-ecs"
  vpc_id = module.vpc.vpc_id

  # Internet-facing: o ALB fica nas subnets publicas e as tasks ECS nas privadas.
  subnets            = module.vpc.public_subnet_ids
  security_group_ids = [module.sg_alb.id]

  # awsvpc registra os ENIs das tasks como alvos, por isso target_type "ip".
  target_type = "ip"

  # A porta do target group e so o default do alvo: o servico ECS registra os ENIs
  # com o container_port explicito. Mantida igual a `app_port` para nao divergir.
  target_port = var.app_port

  health_check = {
    path    = var.app_health_check_path
    matcher = "200"
  }
}

##########################
# Servico da aplicacao
##########################

module "sg_ecs_tasks" {
  source = "./modules/security-group"

  name        = "${var.name}-ecs-tasks"
  description = "Tasks ECS do encurtador"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    alb = {
      description                  = "Somente o ALB alcanca a porta da aplicacao"
      referenced_security_group_id = module.sg_alb.id
      from_port                    = var.app_port
      ip_protocol                  = "tcp"
    }
  }

  egress_rules = {
    all = {
      description = "Saida para ECR, CloudWatch e demais servicos via NAT"
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }
}

module "ecs_app" {
  source = "./modules/ecs"

  name   = "${var.name}-ecs"
  region = var.region

  # Tasks nas subnets privadas: a saida para o ECR passa pelo NAT e a entrada so
  # vem do ALB.
  subnets            = module.vpc.private_subnet_ids
  security_group_ids = [module.sg_ecs_tasks.id]

  image          = "${module.ecr.repository_url}:${var.app_image_tag}"
  container_name = var.name
  container_port = var.app_port

  cpu    = var.app_cpu
  memory = var.app_memory

  # A imagem nao carrega arquivo de ambiente: tudo o que o processo le no boot
  # entra aqui. Endpoints saem dos proprios modulos, entao recriar banco ou cache
  # atualiza a configuracao sozinho.
  environment = {
    PORT = tostring(var.app_port)

    DB_HOST = module.rds.address
    DB_PORT = tostring(module.rds.port)
    DB_USER = var.db_username
    DB_NAME = module.rds.db_name
    # O Postgres 17 recusa conexao sem TLS por padrao; `require` cifra sem exigir
    # bundle de CA dentro da imagem.
    DB_SSLMODE = "require"

    # O cliente monta o endereco como REDIS_URL:REDIS_PORT, entao aqui vai o host
    # puro. Sem TLS e sem senha: o cache so e alcancavel de dentro da VPC.
    REDIS_URL  = module.redis.address
    REDIS_PORT = tostring(module.redis.port)
    REDIS_TLS  = "false"
  }

  # Referencia ao parametro, nunca o valor: o segredo nao aparece na task
  # definition. O modulo cria sozinho a policy que autoriza a role de execucao a
  # ler exatamente estes dois ARNs.
  secrets = {
    DB_PASSWORD = module.ssm_db_password.arn
    JWT_SECRET  = module.ssm_jwt_secret.arn
  }

  target_group_arn = module.alb.target_group_arn

  desired_count = var.app_desired_count

  autoscaling = {
    min_capacity = var.app_desired_count
    max_capacity = var.app_max_capacity
    cpu_target   = 70
  }

  container_insights = true
}
