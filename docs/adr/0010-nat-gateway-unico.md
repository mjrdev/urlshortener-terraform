# ADR 0010 — NAT gateway unico, com HA como opcao de ambiente

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

As tasks ECS ficam em subnets privadas ([ADR-0004](0004-ecs-fargate-atras-de-alb.md))
e dependem de saida para a internet: puxar imagem do ECR, escrever no CloudWatch,
falar com APIs da AWS. Essa saida passa por NAT gateway. O NAT e o item mais caro
desta infraestrutura — cobra por hora, por AZ, e ainda por GB processado. Com tres
AZs, um NAT por AZ triplica o custo fixo de um ambiente que passa a maior parte do
tempo ocioso.

## Decisao

`modules/vpc` calcula `nat_gateway_count = var.single_nat_gateway ? 1 : var.subnet_count`
e cria as route tables privadas na mesma quantidade. Com `single_nat_gateway = true`
todas as subnets privadas apontam para a mesma route table; com `false`, cada AZ
tem NAT e route table proprios.

Em `environments/prod.tfvars` a escolha atual e `single_nat_gateway = true` com
`subnet_count = 3` — e o comentario no arquivo registra a troca: mais barato, ao
custo de virar ponto unico de falha para a saida das privadas.

As subnets sao derivadas do CIDR por `cidrsubnet(var.vpc_cidr, 8, i)` para as
publicas e `i + subnet_count` para as privadas, e as AZs vem de
`aws_availability_zones` filtrando `opt-in-not-required` — nada disso e escrito a
mao por ambiente.

## Alternativas consideradas

- **Um NAT por AZ** — elimina o ponto unico de falha e o trafego cross-AZ, mas
  multiplica o custo fixo por tres. Continua disponivel via flag, para quando o
  ambiente justificar.
- **VPC endpoints para ECR, S3 e CloudWatch Logs** — cortaria a maior parte do
  trafego que hoje passa pelo NAT, e o gateway endpoint de S3 e gratuito. Nao
  elimina o NAT (ainda ha saida para outros destinos) e acrescenta interface
  endpoints, que tambem cobram por hora. Vale reavaliar quando o volume de pull de
  imagem crescer.
- **Sem subnets privadas**, tasks com IP publico — remove o NAT inteiro, mas expoe
  as tasks; recusado no ADR-0004.

## Consequencias

- **A saida das subnets privadas tem ponto unico de falha.** Se a AZ do NAT cair,
  as tasks das outras AZs continuam recebendo trafego do ALB mas nao conseguem
  puxar imagem nova nem enviar log — o servico degrada de um jeito nao obvio.
- Todo o trafego de saida atravessa uma AZ, entao ha custo de transferencia
  cross-AZ alem do custo por GB do NAT.
- Trocar `single_nat_gateway` de `true` para `false` **recria as route tables
  privadas e as associacoes**, com uma interrupcao curta na saida — nao e mudanca
  transparente.
- `subnet_count` e limitado pelo `/16` e pelo `cidrsubnet(..., 8, ...)`: ha espaco
  de sobra para as tres AZs atuais, mas o esquema de enderecamento assume que
  publicas ocupam `0..n-1` e privadas `n..2n-1`.
