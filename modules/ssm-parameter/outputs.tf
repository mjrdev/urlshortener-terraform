# Sem output do valor de proposito: o consumidor precisa do ARN para o
# `valueFrom` da task definition, nunca do segredo em si.
output "arn" {
  description = "ARN do parametro — use no `secrets` da task definition."
  value       = aws_ssm_parameter.this.arn
}

output "name" {
  description = "Nome (caminho) do parametro."
  value       = aws_ssm_parameter.this.name
}
