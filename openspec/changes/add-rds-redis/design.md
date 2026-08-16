## Context

Ver `proposal.md` — Why. O que molda a solucao aqui sao as restricoes ja existentes no
repositorio:

- Raiz composicional: nenhum `resource` mora na raiz, so instancia de modulo local
  (ADR-0003). Servico novo = pasta nova em `modules/`.
- `module.iam_terraform` tem politica escopada, nao `AdministratorAccess` (ADR-0014), e
  esta **no teto da AWS de 10 politicas gerenciadas por role**. Servico novo exige acao
  nova — e nao ha slot livre.
- `modules/ecs` ja tem os inputs `environment` (map) e `secrets` (map de nome para ARN) e
  cria sozinho a policy de leitura de segredo quando `secrets` vem preenchido.
- O ambiente e descartavel (ADR-0013) e o deploy da aplicacao nao passa pelo Terraform
  (ADR-0005).
- O app le `PORT`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`,
  `DB_SSLMODE`, `REDIS_URL`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_TLS` e `JWT_SECRET`.
  `REDIS_URL` e so o host: o cliente monta `Addr` como `REDIS_URL:REDIS_PORT`.

## Goals / Non-Goals

**Goals:**

- Modulos `rds`, `elasticache` e `ssm-parameter` reusaveis, no mesmo formato dos demais.
- Caber no limite de 10 politicas da role da pipeline sem afrouxar escopo existente.
- Task ECS recebendo configuracao completa, com segredo por referencia.

**Non-Goals:**

- Executar migracao de schema (`cmd/migrate`) — decidido separadamente.
- Rotacao de segredo, replica de leitura, Multi-AZ, backup longo, snapshot final.
- Modo cluster no Redis e TLS no cache.
- Mudanca de codigo na aplicacao.

## Decisions

### 1. Parameter Store SecureString, nao Secrets Manager

Parameter Store Standard e gratuito; Secrets Manager custaria ~US$0,40 por segredo/mes e
so pagaria a si mesmo com rotacao gerenciada, que nao esta no escopo. A senha nasce de
`random_password` e vai para um `aws_ssm_parameter` com `type = "SecureString"` sob a
chave gerenciada `alias/aws/ssm`.

Consequencia aceita: a senha fica no state (bucket privado e versionado). Com Secrets
Manager e `manage_master_user_password` ela nunca estaria la — e o motivo para reconsiderar
se o ambiente deixar de ser descartavel.

Chave gerenciada e nao CMK tambem simplifica a role de execucao das tasks: com
`alias/aws/ssm`, `ssm:GetParameters` basta e nao e preciso `kms:Decrypt` — que e
exatamente o que `modules/ecs` ja concede a partir do input `secrets`. **Nenhuma mudanca
em `modules/ecs`.**

### 2. Consolidar politicas para caber no limite de 10

Duas entradas novas sao necessarias (`data-stores` e `ssm`), e nao ha slot. As entradas
`ecs`, `elb` e `autoscaling` ja usam `resources = ["*"]` — juntar as tres numa entrada
`compute` nao afrouxa nada, porque `modules/iam` gera um statement por chave do mapa e o
escopo delas ja vinha da lista de acoes, nao do recurso. Isso libera dois slots.

- `data-stores` — acoes de `rds` + `elasticache`, com `resources` listando os ARNs dos
  dois servicos com o prefixo do projeto. Uma acao de RDS nunca autoriza sobre um ARN de
  ElastiCache, entao a uniao nao amplia poder efetivo. Alternativa descartada: duas
  entradas, que estourariam o limite.
- `ssm` — `ssm:PutParameter`, `GetParameter(s)`, `DeleteParameter`, `AddTagsToResource`,
  `ListTagsForResource` no prefixo `parameter/${var.name}/*`, mais `kms:Decrypt` e
  `kms:DescribeKey`. O Terraform le o parametro com decriptacao no refresh, e a chave
  gerenciada delega a autorizacao ao IAM. `kms:Describe*`/`Decrypt` ficam com o ARN de
  chave da propria conta; `ssm:DescribeParameters` fica **de fora** de proposito — e
  operacao de listagem, exigiria `"*"` e o Terraform nao precisa dela.

Alternativa descartada: pedir aumento de quota de politicas a AWS — depende de ticket e
nao resolve para quem clonar o repositorio.

### 3. `modules/rds` — instancia unica, parametrizada

`aws_db_instance` + `aws_db_subnet_group`, sem `aws_db_parameter_group` proprio (o default
da familia ja liga `rds.force_ssl`, que e o que queremos). Defaults de custo minimo:
`db.t4g.micro`, `gp3` 20 GB, `multi_az = false`, `backup_retention_period = 1`,
`performance_insights_enabled = false`, `skip_final_snapshot = true`,
`deletion_protection = false`, `publicly_accessible = false`, `storage_encrypted = true`
(nao custa nada com a chave gerenciada).

`engine_version` recebe so o major (`"17"`), com `auto_minor_version_upgrade = true`: o
patch fica com a AWS e nao vira diff no plan a cada release.

Output `endpoint` entrega host sem porta (`address`) alem do endpoint completo — o app
espera `DB_HOST` e `DB_PORT` separados.

### 4. `modules/elasticache` — no unico com `aws_elasticache_cluster`

`aws_elasticache_cluster` com `num_cache_nodes = 1`, nao `aws_elasticache_replication_group`:
sem replica, sem failover e sem grupo, e o recurso mais simples que entrega o cache mais
barato. Engine `valkey` (compativel com o protocolo Redis e com o cliente `go-redis`), tipo
`cache.t4g.micro`, `transit_encryption_enabled = false` e sem auth token — o app conecta
com `REDIS_TLS=false` e `REDIS_PASSWORD` vazio, sem mudanca de codigo.

O isolamento vem da rede (subnets privadas + security group so com origem nas tasks), nao
de senha. Alternativa descartada: TLS + auth token, que exigiria `REDIS_TLS=true` e um
segredo a mais para um cache que so e alcancavel de dentro da VPC.

Output `address` entrega `cache_nodes[0].address` — de novo host e porta separados.

### 5. `modules/ssm-parameter` — modulo fino

Um `aws_ssm_parameter` parametrizado por `name`, `value`, `type` e `tags`, com
`value` marcado `sensitive`. Existe para nao quebrar a regra de "nenhum `resource` na
raiz" (ADR-0003) e para padronizar o prefixo `/${var.name}/`.

### 6. Fiacao na raiz: `datastores.tf`

Arquivo novo `datastores.tf` com `sg_rds`, `sg_redis`, `module.rds`, `module.redis`, os
`random_password` e os dois `module.ssm_*`. Nome escolhido para nao se confundir com
blocos `data`. `app.tf` muda so em `module.ecs_app`, ganhando `environment` e `secrets`.

`DB_SSLMODE` vai como `require`: o Postgres 17 recusa conexao sem TLS por padrao e o
driver aceita `require` sem precisar de bundle de CA.

### 7. Ordem de destroy

Os `-target` novos entram em `terraform-destroy.yaml` **antes** dos targets de rede: a VPC
nao sai enquanto houver subnet group ou ENI de banco. Segue o mesmo criterio do ADR-0008.

## Risks / Trade-offs

- **Banco sem schema** → a task sobe e o `/health` passa, mas as rotas de API falham ate
  alguem rodar `cmd/migrate`. Fora do escopo desta mudanca; a task fica registrada como
  proximo passo, e a decisao de como executar (task one-off, ECS Exec ou init container)
  vira mudanca propria.
- **Senha no state** → aceito conscientemente (decisao 1); mitigado pelo bucket privado e
  versionado, e reversivel trocando para Secrets Manager.
- **Consolidacao de politicas altera recursos IAM existentes** → o apply destroi tres
  politicas e cria uma; entre um passo e outro a role fica sem as acoes de ECS/ELB. Um
  apply interrompido no meio exige reaplicar, nao ha rollback automatico. Mitigacao:
  aplicar a mudanca de IAM sozinha primeiro, antes dos recursos novos.
- **RDS leva de 5 a 10 minutos para ficar disponivel** → o primeiro apply fica longo e o
  job da pipeline pode esbarrar no timeout padrao do runner. Mitigacao: primeiro apply
  local, ou aceitar o tempo.
- **`db.t4g.micro` e `cache.t4g.micro` sao burstable** → sob carga sustentada os creditos
  de CPU acabam e a latencia sobe. Aceito: e ambiente de projeto pessoal, e a classe e
  input do modulo.
- **`aws_elasticache_cluster` com engine `valkey`** exige provider AWS recente; o root fixa
  `~> 6.0`, que atende. Se der incompatibilidade, cair para `engine = "redis"` e a mesma
  classe de no, sem impacto no app.

## Migration Plan

1. Aplicar so a consolidacao de politicas em `iam.tf` (`terraform apply -target=module.iam_terraform`).
2. Aplicar o restante: SSM, RDS, ElastiCache, security groups.
3. Aplicar a nova revisao da task definition com `environment` e `secrets` — o servico so
   passa a usa-la no proximo deploy da aplicacao (ADR-0005), entao disparar a pipeline do
   app depois.
4. Rollback: `terraform destroy -target` dos modulos novos e reverter `app.tf`. O servico
   volta para a revisao anterior no deploy seguinte; nada em ECS precisa ser desfeito a mao.

## Open Questions

- Nome do parametro do JWT: `/urlshortener/jwt-secret` gerado pelo Terraform ou valor
  fornecido por quem opera? A implementacao assume gerado, e trocar depois e so mudar o
  valor do parametro — nao muda spec, modulos nem tarefas.
