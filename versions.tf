terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Backend parcial: a `key` vem de environments/<env>.backend.hcl, para cada
  # ambiente ter seu proprio state no mesmo bucket.
  #   terraform init -backend-config=environments/prod.backend.hcl
  backend "s3" {
    bucket = "mjr-terraform"
    region = "us-east-1"
  }
}
