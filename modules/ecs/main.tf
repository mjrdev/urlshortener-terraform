##########################
# Cluster
##########################

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }

  tags = merge({ Name = var.name }, var.tags)
}

# FARGATE_SPOT fica sempre disponivel no cluster, mas so recebe tasks se aparecer
# em capacity_provider_strategy — sem estrategia o servico usa launch_type FARGATE.
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

##########################
# Logs
##########################

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_in_days

  tags = merge({ Name = "/ecs/${var.name}" }, var.tags)
}

##########################
# IAM
##########################

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Role usada pelo agente do ECS (puxar imagem do ECR, escrever logs, ler segredos),
# nao pelo processo dentro do container.
resource "aws_iam_role" "execution" {
  count = var.execution_role_arn == null ? 1 : 0

  name               = "${var.name}-execution"
  description        = "Role de execucao das tasks ECS de ${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge({ Name = "${var.name}-execution" }, var.tags)
}

resource "aws_iam_role_policy_attachment" "execution" {
  count = var.execution_role_arn == null ? 1 : 0

  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# A policy gerenciada nao cobre secretsmanager/ssm; so cria o acesso quando ha
# segredos declarados, com escopo nos ARNs realmente usados.
data "aws_iam_policy_document" "secrets" {
  count = var.execution_role_arn == null && length(var.secrets) > 0 ? 1 : 0

  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "ssm:GetParameters",
    ]
    resources = values(var.secrets)
  }
}

resource "aws_iam_role_policy" "secrets" {
  count = var.execution_role_arn == null && length(var.secrets) > 0 ? 1 : 0

  name   = "${var.name}-secrets"
  role   = aws_iam_role.execution[0].id
  policy = data.aws_iam_policy_document.secrets[0].json
}

# Role assumida pelo container — e nela que entram as permissoes da aplicacao
# (DynamoDB, S3, etc.).
resource "aws_iam_role" "task" {
  count = var.task_role_arn == null ? 1 : 0

  name               = "${var.name}-task"
  description        = "Role assumida pelos containers de ${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge({ Name = "${var.name}-task" }, var.tags)
}

data "aws_iam_policy_document" "task" {
  for_each = var.task_role_arn == null ? var.task_policies : {}

  statement {
    effect    = each.value.effect
    actions   = each.value.actions
    resources = each.value.resources
  }
}

resource "aws_iam_role_policy" "task" {
  for_each = var.task_role_arn == null ? var.task_policies : {}

  name   = "${var.name}-${each.key}"
  role   = aws_iam_role.task[0].id
  policy = data.aws_iam_policy_document.task[each.key].json
}

# ECS Exec abre um canal do SSM para dentro da task; sem estas acoes o
# `aws ecs execute-command` falha mesmo com enable_execute_command ligado.
data "aws_iam_policy_document" "exec" {
  count = var.task_role_arn == null && var.enable_execute_command ? 1 : 0

  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "exec" {
  count = var.task_role_arn == null && var.enable_execute_command ? 1 : 0

  name   = "${var.name}-execute-command"
  role   = aws_iam_role.task[0].id
  policy = data.aws_iam_policy_document.exec[0].json
}

locals {
  execution_role_arn = coalesce(var.execution_role_arn, one(aws_iam_role.execution[*].arn))
  task_role_arn      = coalesce(var.task_role_arn, one(aws_iam_role.task[*].arn))
}

##########################
# Task definition
##########################

locals {
  # Sem health check de container o ECS so conhece o estado do target group; com
  # ele, a task e reciclada mesmo sem o ALB na frente. A chave e omitida quando
  # nao ha health check — enviar null gera diff a cada plan.
  container_health_check = var.container_health_check == null ? {} : {
    healthCheck = {
      command     = var.container_health_check.command
      interval    = var.container_health_check.interval
      timeout     = var.container_health_check.timeout
      retries     = var.container_health_check.retries
      startPeriod = var.container_health_check.start_period
    }
  }

  container_definitions = [
    merge(local.container_health_check, {
      name      = var.container_name
      image     = var.image
      essential = true

      portMappings = [
        {
          name          = "${var.container_name}-${var.container_port}"
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        for key, value in var.environment : {
          name  = key
          value = value
        }
      ]

      # valueFrom recebe o ARN do segredo; o valor e injetado na partida da task
      # e nunca aparece no state nem na task definition.
      secrets = [
        for key, arn in var.secrets : {
          name      = key
          valueFrom = arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }

    })
  ]
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = local.execution_role_arn
  task_role_arn            = local.task_role_arn

  runtime_platform {
    cpu_architecture        = var.cpu_architecture
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode(local.container_definitions)

  tags = merge({ Name = var.name }, var.tags)
}

##########################
# Service
##########################

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  # Com estrategia definida o launch_type precisa ficar vazio — os dois campos
  # sao mutuamente exclusivos na API.
  launch_type = length(var.capacity_provider_strategy) > 0 ? null : "FARGATE"

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy

    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  enable_execute_command = var.enable_execute_command
  propagate_tags         = "SERVICE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [var.target_group_arn]

    content {
      target_group_arn = load_balancer.value
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  # Enquanto o ALB nao aprova a task, o ECS a considera unhealthy; a carencia
  # cobre o tempo de boot da aplicacao.
  health_check_grace_period_seconds = var.target_group_arn == null ? null : var.health_check_grace_period

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  # Falhou o deploy, volta sozinho para a revisao anterior em vez de deixar o
  # servico preso tentando subir a task quebrada.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  wait_for_steady_state = var.wait_for_steady_state

  tags = merge({ Name = var.name }, var.tags)

  lifecycle {
    # O deploy da aplicacao (pipeline do app) troca a task definition e o
    # autoscaling mexe no desired_count — o Terraform nao deve reverter nenhum
    # dos dois no proximo apply.
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]
}

##########################
# Autoscaling
##########################

resource "aws_appautoscaling_target" "this" {
  count = var.autoscaling == null ? 0 : 1

  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.autoscaling.min_capacity
  max_capacity       = var.autoscaling.max_capacity

  tags = merge({ Name = var.name }, var.tags)
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.autoscaling == null ? 0 : (var.autoscaling.cpu_target == null ? 0 : 1)

  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling.cpu_target
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown
    scale_out_cooldown = var.autoscaling.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count = var.autoscaling == null ? 0 : (var.autoscaling.memory_target == null ? 0 : 1)

  name               = "${var.name}-memory"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling.memory_target
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown
    scale_out_cooldown = var.autoscaling.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
