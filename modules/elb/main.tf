##########################
# Load balancer
##########################

resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = var.security_group_ids
  subnets            = var.subnets

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout
  drop_invalid_header_fields = var.drop_invalid_header_fields

  # Sem bucket configurado o bloco nao e criado — access logs exigem um bucket
  # que ja exista e com policy liberando o servico de logs da AWS.
  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [var.access_logs_bucket]

    content {
      bucket  = access_logs.value
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = merge({ Name = var.name }, var.tags)
}

##########################
# Target group
##########################

# target_type "ip" e o modo exigido por tasks ECS em awsvpc: os alvos sao os ENIs
# das tasks, registrados e removidos pelo proprio servico ECS.
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  vpc_id      = var.vpc_id
  target_type = var.target_type
  port        = var.target_port
  protocol    = var.target_protocol

  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    path                = var.health_check.path
    port                = var.health_check.port
    protocol            = var.target_protocol
    matcher             = var.health_check.matcher
    interval            = var.health_check.interval
    timeout             = var.health_check.timeout
    healthy_threshold   = var.health_check.healthy_threshold
    unhealthy_threshold = var.health_check.unhealthy_threshold
  }

  tags = merge({ Name = "${var.name}-tg" }, var.tags)

  # O target group nao pode ser destruido enquanto estiver referenciado por um
  # listener; criar o novo antes evita o erro ao mudar atributos que forcam
  # recriacao (name, port, protocol, target_type).
  lifecycle {
    create_before_destroy = true
  }
}

##########################
# Listeners
##########################

locals {
  # Com certificado, a porta 80 so redireciona. Sem certificado, ela e a unica
  # porta de entrada e precisa entregar o trafego ao target group.
  https_enabled = var.certificate_arn != null
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.https_enabled ? [1] : []

    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.https_enabled ? [] : [1]

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }

  tags = merge({ Name = "${var.name}-http" }, var.tags)
}

resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = merge({ Name = "${var.name}-https" }, var.tags)
}
