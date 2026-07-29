output "arn" {
  description = "ARN do provider OIDC — passar para cada modulo de role."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "url" {
  description = "URL do provider, com esquema."
  value       = aws_iam_openid_connect_provider.this.url
}

output "host" {
  description = "Host sem esquema — usado ao montar as condicoes `aud` e `sub`."
  value       = var.oidc_host
}
