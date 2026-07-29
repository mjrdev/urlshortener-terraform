resource "aws_ecr_repository" "ecr_repo" {
  name = var.name
  # IMMUTABLE impede sobrescrever uma tag ja publicada; nao existe "READ_ONLY".
  image_tag_mutability = var.immutable_tags ? "IMMUTABLE" : "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}