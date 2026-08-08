terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Range aberto de proposito: quem consome o modulo e que fixa a versao.
      version = ">= 6.0"
    }
  }
}
