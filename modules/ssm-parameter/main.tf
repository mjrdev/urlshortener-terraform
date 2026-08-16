# SecureString usa a chave gerenciada `alias/aws/ssm` quando `key_id` fica nulo.
# E de proposito: com a chave gerenciada a role de execucao das tasks precisa so
# de `ssm:GetParameters` para ler o segredo — uma CMK exigiria `kms:Decrypt`
# tambem, sem beneficio nenhum aqui.
resource "aws_ssm_parameter" "this" {
  name        = var.name
  description = var.description
  type        = var.type
  value       = var.value
  key_id      = var.key_id
  tier        = var.tier

  tags = merge({ Name = var.name }, var.tags)
}
