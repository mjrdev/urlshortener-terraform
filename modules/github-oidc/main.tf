# O provider OIDC e unico por conta AWS: um so recurso atende todas as
# roles de todos os repositorios. Por isso vive num modulo separado,
# instanciado uma unica vez.

resource "aws_iam_openid_connect_provider" "this" {
  # A AWS valida o certificado do GitHub pelas CAs raiz dela, entao
  # thumbprint_list nao e necessario.
  url            = "https://${var.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "github-actions-oidc"
  }
}
