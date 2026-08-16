# `address` e o host puro e `endpoint` traz host:porta. A aplicacao espera host e
# porta em variaveis separadas (DB_HOST / DB_PORT), por isso os dois existem.
output "address" {
  description = "Host da instancia, sem porta."
  value       = aws_db_instance.this.address
}

output "endpoint" {
  description = "Endpoint no formato host:porta."
  value       = aws_db_instance.this.endpoint
}

output "port" {
  description = "Porta do banco."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nome do banco criado na instancia."
  value       = aws_db_instance.this.db_name
}

output "arn" {
  description = "ARN da instancia — use ao escopar politicas IAM."
  value       = aws_db_instance.this.arn
}

output "identifier" {
  description = "Identificador da instancia."
  value       = aws_db_instance.this.identifier
}
