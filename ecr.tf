module "ecr" {
  source = "./modules/ecr"

  name = "${var.name}-ecr"
}
