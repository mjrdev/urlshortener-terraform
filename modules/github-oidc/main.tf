# O provider OIDC e unico por conta AWS: um so recurso atende todas as
# roles de todos os repositorios. Por isso vive num modulo separado,
# instanciado uma unica vez.


resource "aws_iam_openid_connect_provider" "this" {
  count = var.prevent_destroy ? 0 : 1

  # A AWS valida o certificado do GitHub pelas CAs raiz dela, entao
  # thumbprint_list nao e necessario.
  url            = "https://${var.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "github-actions-oidc"
  }
}

resource "aws_iam_openid_connect_provider" "protected" {
  count = var.prevent_destroy ? 1 : 0

  url            = "https://${var.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "github-actions-oidc"
  }

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  provider_arn = one(concat(aws_iam_openid_connect_provider.this[*].arn, aws_iam_openid_connect_provider.protected[*].arn))
  provider_url = one(concat(aws_iam_openid_connect_provider.this[*].url, aws_iam_openid_connect_provider.protected[*].url))
}
