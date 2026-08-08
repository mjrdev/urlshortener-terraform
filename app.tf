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

  # MODO SANDBOX: o target group aponta para o nginx de `sandbox.tf` — porta 80 e
  # raiz do site, porque a imagem publica do nginx nao tem /health e responderia
  # 404, deixando o alvo unhealthy para sempre.
  # Ao reativar `module.ecs_app`, voltar para:
  #   target_port  = var.app_port
  #   health_check = { path = var.app_health_check_path, matcher = "200" }
  target_port = 80

  health_check = {
    path    = "/"
    matcher = "200"
  }
}

##########################
# Servico da aplicacao — DESATIVADO
##########################
#
# O servico do encurtador esta comentado enquanto o ambiente serve para validar o
# ECS com o nginx de `sandbox.tf`, que hoje ocupa o target group do ALB.
#
# Para reativar:
#   1. Descomentar `module.sg_ecs_tasks` e `module.ecs_app` abaixo.
#   2. Em `module.alb`, voltar target_port/health_check para var.app_port e
#      var.app_health_check_path (ha um comentario no bloco).
#   3. Em `sandbox.tf`, remover `target_group_arn` do nginx e voltar
#      `cluster_arn = module.ecs_app.cluster_arn` — dois servicos nao podem
#      dividir o mesmo target group.
#   4. Descomentar os outputs do app em `outputs.tf` e os `-target` no workflow
#      de destroy.
#   5. Garantir que a imagem existe no ECR na tag de `app_image_tag`.

# module "sg_ecs_tasks" {
#   source = "./modules/security-group"
#
#   name        = "${var.name}-ecs-tasks"
#   description = "Tasks ECS do encurtador"
#   vpc_id      = module.vpc.vpc_id
#
#   ingress_rules = {
#     alb = {
#       description                  = "Somente o ALB alcanca a porta da aplicacao"
#       referenced_security_group_id = module.sg_alb.id
#       from_port                    = var.app_port
#       ip_protocol                  = "tcp"
#     }
#   }
#
#   egress_rules = {
#     all = {
#       description = "Saida para ECR, CloudWatch e demais servicos via NAT"
#       cidr_ipv4   = "0.0.0.0/0"
#       ip_protocol = "-1"
#     }
#   }
# }

# module "ecs_app" {
#   source = "./modules/ecs"
#
#   name   = "${var.name}-ecs"
#   region = var.region
#
#   # Tasks nas subnets privadas: a saida para o ECR passa pelo NAT e a entrada so
#   # vem do ALB.
#   subnets            = module.vpc.private_subnet_ids
#   security_group_ids = [module.sg_ecs_tasks.id]
#
#   image          = "${module.ecr.repository_url}:${var.app_image_tag}"
#   container_name = var.name
#   container_port = var.app_port
#
#   cpu    = var.app_cpu
#   memory = var.app_memory
#
#   environment = {
#     PORT = tostring(var.app_port)
#   }
#
#   target_group_arn = module.alb.target_group_arn
#
#   desired_count = var.app_desired_count
#
#   autoscaling = {
#     min_capacity = var.app_desired_count
#     max_capacity = var.app_max_capacity
#     cpu_target   = 70
#   }
# }
