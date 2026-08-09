# Recursos descartaveis de teste. Este arquivo pode ser apagado inteiro quando o
# ambiente de validacao nao for mais necessario — nada fora dele depende daqui.

module "sg_ecs_nginx" {
  source = "./modules/security-group"

  name        = "${var.name}-ecs-nginx"
  description = "Servico de teste nginx no cluster ECS"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    alb = {
      description                  = "Trafego vindo do ALB, que hoje aponta para o nginx"
      referenced_security_group_id = module.sg_alb.id
      from_port                    = 80
      ip_protocol                  = "tcp"
    }

    vpc = {
      description = "HTTP de dentro da VPC (teste sem passar pelo ALB)"
      cidr_ipv4   = module.vpc.vpc_cidr
      from_port   = 80
      ip_protocol = "tcp"
    }
  }

  egress_rules = {
    all = {
      description = "Saida para o Docker Hub, CloudWatch e SSM via NAT"
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }

}

# Servico descartavel para validar cluster, rede e permissoes sem depender do
# build da aplicacao. Enquanto `module.ecs_app` esta comentado, este servico e o
# unico do ambiente: cria o proprio cluster e recebe o trafego do ALB.
#
# Ao reativar o app, voltar a `cluster_arn = module.ecs_app.cluster_arn` (para
# dividir o cluster) e remover o `target_group_arn` daqui — o target group so
# pode ter um servico registrado.
module "ecs_nginx" {
  source = "./modules/ecs"

  name   = "${var.name}-nginx"
  region = var.region

  subnets            = module.vpc.private_subnet_ids
  security_group_ids = [module.sg_ecs_nginx.id]

  image          = "public.ecr.aws/nginx/nginx:stable"
  container_name = "nginx"
  container_port = 80

  cpu    = 256
  memory = 512

  # Registrado no target group do ALB: o nginx responde 200 na raiz, que e o
  # health check configurado em `app.tf` enquanto o ambiente esta em sandbox.
  target_group_arn = module.alb.target_group_arn

  desired_count          = var.nginx_desired_count
  enable_execute_command = true

  log_retention_in_days = 3
}
