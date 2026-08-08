# ADR 0004 — ECS Fargate em subnets privadas atras de um ALB publico

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

O encurtador e uma aplicacao HTTP stateless em container, que precisa de entrada
pela internet, escala horizontal e nenhum servidor para administrar. A imagem vem
do ECR da propria conta.

## Decisao

Topologia: **internet → ALB (subnets publicas) → tasks ECS Fargate (subnets
privadas) → saida para ECR/CloudWatch pelo NAT**.

- **Fargate**, sem instancias EC2 no cluster. `network_mode = "awsvpc"`, cada task
  com seu proprio ENI.
- **ALB internet-facing** nas subnets publicas, com `target_type = "ip"` — em
  `awsvpc` os alvos registrados sao os ENIs das tasks, nao instancias.
- **Tasks em subnets privadas**, sem IP publico. A unica entrada e o security
  group do ALB: `module.sg_ecs_tasks` libera `var.app_port` apenas para
  `module.sg_alb.id`, por referencia de SG e nao por CIDR.
- **Autoscaling por target tracking de CPU** (alvo 70%), com `min_capacity` igual
  ao `desired_count` do ambiente.
- **Deployment circuit breaker com rollback ligado**: deploy que nao estabiliza
  volta sozinho para a revisao anterior.
- O modulo `elb` cria o listener 80 como redirect para 443 quando ha
  `certificate_arn`, e como forward direto ao target group quando nao ha — hoje
  nao ha certificado, entao a entrada e HTTP puro.

## Alternativas consideradas

- **ECS em EC2** — mais barato em escala constante e permite tipos de instancia
  especificos, mas traz patching, capacity providers com autoscaling group e
  draining de instancia. Nao se paga para uma aplicacao deste tamanho.
- **Tasks em subnet publica com IP publico** — dispensa o NAT e sua conta mensal,
  mas expoe cada task diretamente e faz do security group a unica barreira.
- **Lambda + API Gateway** — encaixa bem no perfil de trafego de um encurtador e
  sai mais barato ocioso, porem muda o modelo de empacotamento (nao seria a mesma
  imagem de container) e o objetivo aqui inclui exercitar ECS.
- **API Gateway ou NLB no lugar do ALB** — o NLB nao faz health check HTTP nem
  roteamento por path; o API Gateway HTTP puro nao acrescenta nada sobre o ALB para
  este caso.

## Consequencias

- Nenhum host para manter, e o boot de uma task nova nao depende de capacidade de
  cluster.
- **A saida das tasks depende do NAT** ([ADR-0010](0010-nat-gateway-unico.md)):
  puxar imagem do ECR, mandar log para o CloudWatch e falar com qualquer API AWS
  passa por ele. Sem VPC endpoints, esse trafego e cobrado por GB.
- O `health_check_grace_period` so e aplicado quando ha target group; sem ele o
  ECS mataria a task antes do primeiro health check passar.
- O target group usa `create_before_destroy` porque nao pode ser destruido enquanto
  um listener o referencia — mudar `name`, `port`, `protocol` ou `target_type`
  recria o recurso.
- **Trafego ainda em HTTP.** Habilitar HTTPS e passar `certificate_arn` ao modulo
  `elb`; o redirect 80 → 443 ja esta escrito e passa a valer sozinho.
- Ha um limite pratico de tasks por AZ dado pelo CIDR das subnets privadas — cada
  task consome um IP.
