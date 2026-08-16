## Why

A aplicacao nao sobe na infraestrutura atual. O `cmd/api/main.go` chama `config.Db()` e
`config.Rdb()` no boot: sem Postgres o `gorm.Open` da `panic` e a task morre antes de
responder ao health check, e o deployment circuit breaker faz rollback. Hoje a infra tem
VPC, ALB, ECR e ECS — e nenhum banco, nenhum cache e nenhum lugar para guardar segredo.
A task definition passa so `PORT`, enquanto o app le `DB_*`, `REDIS_*` e `JWT_SECRET`.

Ou seja: o fluxo de deploy ja esta pronto (ADR-0005), mas nao ha o que fazer subir.

## What Changes

- **Modulo `modules/rds`** — instancia Postgres em subnets privadas, com subnet group,
  parameter group e a senha gerada pelo Terraform. Perfil de custo minimo:
  `db.t4g.micro`, 20 GB gp3, Single-AZ, backup de 1 dia, sem Performance Insights.
- **Modulo `modules/elasticache`** — no unico Redis/Valkey (`cache.t4g.micro`), sem
  replica, sem Multi-AZ, sem TLS e sem auth token, alcancavel apenas de dentro da VPC.
- **Modulo `modules/ssm-parameter`** — parametros SecureString para a senha do banco e o
  `JWT_SECRET`. Parameter Store Standard e gratuito; Secrets Manager custaria ~US$0,40
  por segredo/mes e nao traz beneficio aqui.
- **Novos security groups** `sg_rds` e `sg_redis` no root, cada um aceitando trafego so
  do `module.sg_ecs_tasks` — nada de CIDR aberto, nada de acesso publico.
- **`module.ecs_app` passa a receber as variaveis do app**: `DB_HOST`, `DB_PORT`,
  `DB_USER`, `DB_NAME`, `DB_SSLMODE`, `REDIS_URL`, `REDIS_PORT`, `REDIS_TLS` em
  `environment`, e `DB_PASSWORD` + `JWT_SECRET` em `secrets` (o modulo ja cria sozinho a
  policy de leitura quando `secrets` vem preenchido).
- **`module.iam_terraform` ganha as acoes novas** de `rds`, `elasticache`, `ssm` e
  `kms:Decrypt`. Como a role esta no teto de 10 politicas gerenciadas da AWS, as acoes
  novas entram em entradas existentes ou exigem consolidacao — decisao que fica no design.
- **`terraform-destroy.yaml` ganha os `-target`** dos modulos novos.
- **ADR novo** registrando os dados gerenciados na VPC e o criterio "mais barato que
  funciona" (Single-AZ, sem replica, ambiente descartavel — coerente com o ADR-0013).

Nao entra nesta mudanca: rotacao de segredos, replica de leitura, Multi-AZ, backup longo,
migracao de schema (o binario `cmd/migrate` existe, mas quem o executa e quando e assunto
separado).

## Capabilities

### New Capabilities
- `rds-postgres`: banco Postgres gerenciado em subnets privadas, dimensionado para custo
  minimo, com credencial gerada e nunca em texto claro no tfvars.
- `elasticache-redis`: cache Redis de no unico dentro da VPC, compativel com o cliente
  `go-redis` do app (sem TLS, sem auth token).
- `app-runtime-config`: as variaveis de ambiente e os segredos que a task ECS do
  encurtador recebe, e de onde eles vem.

### Modified Capabilities
<!-- Nenhuma: openspec/specs/ esta vazio, entao todas as capacidades acima sao novas. -->

## Impact

- **Codigo de infra**: novos `modules/rds`, `modules/elasticache`, `modules/ssm-parameter`;
  novo `data.tf` na raiz (ou `app.tf` estendido); `app.tf`, `iam.tf`, `variables.tf`,
  `environments/*.tfvars`, `outputs.tf`.
- **Pipeline**: `.github/workflows/terraform-destroy.yaml` (targets novos). A pipeline do
  app nao muda — ela continua so trocando a imagem da revisao ativa.
- **Aplicacao**: nenhuma mudanca de codigo exigida. O app ja le todas essas variaveis; o
  `DB_SSLMODE` passa a valer `require`, que o driver ja suporta.
- **Custo**: de ~US$35/mes (NAT + ALB) para ~US$60/mes. RDS ~US$12-15, ElastiCache ~US$11,
  Parameter Store US$0.
- **Risco**: o apply cria recursos que levam de 5 a 10 minutos (RDS) e a role da pipeline
  para com `AccessDenied` se as acoes novas nao entrarem antes em `iam.tf`.
