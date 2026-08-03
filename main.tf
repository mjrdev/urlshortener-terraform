terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "mjr-terraform"
    region = "us-east-1"
    key    = "url-shortener/terraform.tfstate"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway
  name               = var.name
}

module "github_oidc" {
  source = "./modules/github-oidc"

  prevent_destroy = true
}

module "shortener-ecr" {
  source = "./modules/ecr"
  name   = "${var.name}-ecr"
}

module "iam_urlshortener" {

  source = "./modules/iam"

  name        = "${var.name}-github-actions"
  description = "Role assumida pelo GitHub Actions de ${var.app_repository}"

  trust_statements = local.github_actions_trust["app"]

  policies = {
    ecr-auth = {
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }

    ecr-push = {
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:ListImages",
      ]
      resources = [module.shortener-ecr.repository_arn]
    }
  }
}

module "iam_terraform" {
  source = "./modules/iam"

  name        = "${var.name}-terraform-github-actions"
  description = "Role da pipeline de infraestrutura (${var.terraform_repository})"

  trust_statements = local.github_actions_trust["terraform"]

  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]

  prevent_destroy = true
}

module "sg-alb" {
  source = "./modules/security-group"

  name        = "${var.name}-alb-ecs"
  description = "ALB cluster ecs"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    http = {
      description = "HTTP publico — redirecionado para HTTPS no listener"
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

module "alb_ecs" {
  source = "./modules/elb"

  name   = "${var.name}-ecs"
  vpc_id = module.vpc.vpc_id

  # Internet-facing: o ALB fica nas subnets publicas e as tasks ECS nas privadas.
  subnets            = module.vpc.public_subnet_ids
  security_group_ids = [module.sg-alb.id]

  # awsvpc registra os ENIs das tasks como alvos, por isso target_type "ip".
  target_type = "ip"
  target_port = var.app_port

  health_check = {
    path    = var.app_health_check_path
    matcher = "200"
  }
}

module "sg-ecs-tasks" {
  source = "./modules/security-group"

  name        = "${var.name}-ecs-tasks"
  description = "Tasks ECS do encurtador"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    alb = {
      description                  = "Somente o ALB alcanca a porta da aplicacao"
      referenced_security_group_id = module.sg-alb.id
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

module "ecs" {
  source = "./modules/ecs"

  name   = "${var.name}-ecs"
  region = var.region

  subnets            = module.vpc.private_subnet_ids
  security_group_ids = [module.sg-ecs-tasks.id]

  image          = "${module.shortener-ecr.repository_url}:${var.app_image_tag}"
  container_name = var.name
  container_port = var.app_port

  cpu    = var.app_cpu
  memory = var.app_memory

  environment = {
    PORT = tostring(var.app_port)
  }

  target_group_arn = module.alb_ecs.target_group_arn

  desired_count = var.app_desired_count

  autoscaling = {
    min_capacity = var.app_desired_count
    max_capacity = var.app_max_capacity
    cpu_target   = 70
  }
}
