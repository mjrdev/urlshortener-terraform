module "vpc" {
  source = "./modules/vpc"

  name               = var.name
  vpc_cidr           = var.vpc_cidr
  subnet_count       = var.subnet_count
  single_nat_gateway = var.single_nat_gateway
}
