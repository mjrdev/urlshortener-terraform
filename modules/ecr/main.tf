resource "aws_ecr_repository" "ecr_repo" {
  name                 = var.name
  image_tag_mutability = var.readonly ? "READ_ONLY" : "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}