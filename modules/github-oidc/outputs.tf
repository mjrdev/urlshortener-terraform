output "arn" {
  description = "ARN do provider OIDC — passar para cada modulo de role."
  value       = local.provider_arn
}

output "url" {
  description = "URL do provider, com esquema."
  value       = local.provider_url
}

output "host" {
  description = "Host sem esquema — usado ao montar as condicoes `aud` e `sub`."
  value       = var.oidc_host
}
