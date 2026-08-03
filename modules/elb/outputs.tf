output "arn" {
  description = "ARN do load balancer."
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "DNS publico do load balancer — alvo do registro CNAME/alias."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Zone id do load balancer, usado em alias record do Route 53."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN do target group — e o valor esperado por aws_ecs_service.load_balancer."
  value       = aws_lb_target_group.this.arn
}

output "target_group_name" {
  description = "Nome do target group."
  value       = aws_lb_target_group.this.name
}

output "http_listener_arn" {
  description = "ARN do listener HTTP."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN do listener HTTPS, ou null quando nao ha certificado."
  value       = one(aws_lb_listener.https[*].arn)
}
