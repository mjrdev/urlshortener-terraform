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
}

module "shortener-ecr" {
  source = "./modules/ecr"
  name = "${var.name}-ecr"
}

module "iam_urlshortener" {
  source = "./modules/iam"

  name        = "${var.name}-github-actions"
  description = "Role assumida pelo GitHub Actions de ${var.github_repository}"

  trust_statements = local.github_actions_trust

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
      resources = [module.ecr.role_arn]
    }
  }
}
