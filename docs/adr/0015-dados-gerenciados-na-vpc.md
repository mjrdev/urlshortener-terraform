# ADR 0015 — Postgres e Redis gerenciados na VPC, no menor porte

- **Status:** aceito
- **Data:** 2026-08-16

## Contexto

A aplicacao abre conexao com Postgres e com Redis no boot: sem banco o processo
morre antes de responder ao health check, e o circuit breaker do servico devolve a
revisao anterior. Ate aqui a infraestrutura tinha rede, ALB, ECR e ECS — e nenhum
lugar para dado nem para segredo. A task recebia apenas `PORT`, enquanto o app le
`DB_*`, `REDIS_*` e `JWT_SECRET`.

E um projeto pessoal: a conta paga NAT e ALB, e cada servico novo pesa no custo
mensal. Ao mesmo tempo, o repositorio e publico e a role da pipeline tem politica
escopada (ADR-0014), com o limite de 10 politicas gerenciadas por role ja no teto.

## Decisao

**Banco e cache sao servicos gerenciados dentro da VPC, no menor porte que
funciona, e o segredo vive no Parameter Store.**

- `modules/rds` — instancia unica `db.t4g.micro`, 20 GB gp3, Single-AZ, backup de
  um dia, Performance Insights desligado, `skip_final_snapshot` e sem
  `deletion_protection`. Sem parameter group proprio: o default da familia ja
  exige TLS, e a aplicacao conecta com `sslmode=require`.
- `modules/elasticache` — `aws_elasticache_replication_group` com **um no**
  `cache.t4g.micro`, engine `valkey`, sem replica, sem failover, sem TLS e sem auth
  token. O recurso de grupo e o unico caminho para Valkey: `aws_elasticache_cluster`
  aceita so `memcached` e `redis` (validado no provider 6.60). Valkey custa cerca de
  20% menos por no que Redis OSS no mesmo tipo, entao o grupo com um no e mais
  barato que o cluster equivalente.
- `modules/ssm-parameter` — senha do banco e chave de assinatura como
  `SecureString` sob a chave gerenciada `alias/aws/ssm`. Os valores nascem de
  `random_password` e a task recebe o **ARN**, nunca o valor.
- Cada servico ganha security group proprio (`sg_rds`, `sg_redis`) cuja unica
  origem de ingress e o security group das tasks. Nada de CIDR aberto, nada de
  endereco publico.
- Para caber no limite de 10 politicas, as entradas `ecs`, `elb` e `autoscaling`
  de `module.iam_terraform` viraram uma so, `compute`. As tres ja usavam
  `resources = ["*"]`, entao a uniao nao afrouxa escopo — libera slot para
  `data-stores` e `ssm`.
- `compute` virou tambem o lugar das **leituras** de RDS, ElastiCache e SSM
  (`rds:Describe*`, `elasticache:Describe*`, `ssm:DescribeParameters`). Sao
  operacoes de listagem: a AWS as avalia contra um ARN generico (`db:*`,
  `parameter/*`), que nenhum escopo por prefixo cobre — o mesmo caso de
  `logs:DescribeLogGroups`. O que muda estado continua escopado por ARN.

## Alternativas consideradas

- **Secrets Manager em vez de Parameter Store** — permitiria
  `manage_master_user_password`, com rotacao gerenciada e a senha fora do state.
  Custa ~US$0,40 por segredo/mes sem que a rotacao esteja no escopo, e exigiria
  `kms:Decrypt` extra na role de execucao das tasks. E a escolha certa no dia em
  que o ambiente deixar de ser descartavel.
- **Container de Postgres/Redis na propria task** — seria o mais barato de todos e
  perderia durabilidade do banco a cada deploy. Aceitavel para cache, nao para
  dado.
- **ElastiCache Serverless** — escala sozinho, mas a cobranca minima de storage e
  ECPU fica acima do no `t4g.micro` para esta carga.
- **Manter as leituras escopadas por ARN** — foi a primeira tentativa e o apply
  parou tres vezes: `rds:DescribeDBInstances` avaliado contra `db:*`,
  `ssm:DescribeParameters` contra `parameter/*` e `elasticache:CreateReplicationGroup`
  contra `parametergroup:*`. Escopo que a API nao suporta nao protege nada, so
  quebra o apply.
- **`aws_elasticache_cluster` com `redis`** — recurso mais simples e sem grupo,
  mas fecha a porta para Valkey e custa ~20% mais por no. Foi a primeira tentativa;
  o plan parou em `expected engine to be one of ["memcached" "redis"]`.
- **Replica ou failover no grupo** — `num_cache_clusters` acima de 1 liga o failover
  sozinho e multiplica o custo; nao ha requisito de HA para um cache que pode nascer
  vazio.
- **Aumento de quota de politicas IAM** — depende de ticket na AWS e nao resolve
  para quem clona o repositorio.

## Consequencias

- Custo mensal sobe de ~US$35 (NAT + ALB) para ~US$60.
- **A senha do banco fica no state.** O bucket e privado e versionado; e o preco
  de nao pagar Secrets Manager, e a reversao e trocar o modulo do segredo.
- Instancias burstable: sob carga sustentada os creditos de CPU acabam e a
  latencia sobe. Classe e input do modulo, entao a saida e um tfvars.
- Sem replica e sem Multi-AZ, uma falha de AZ derruba banco e cache. Coerente com
  o ambiente descartavel do ADR-0013.
- **O banco nasce sem schema.** A task sobe e `/health` passa, mas as rotas de API
  falham ate `cmd/migrate` rodar. Como executar a migracao e decisao propria,
  ainda em aberto.
- O primeiro apply fica longo: a instancia RDS leva de 5 a 10 minutos.
- Mudanca em variavel de ambiente ou segredo cria revisao nova da task
  definition, mas so entra em producao no proximo deploy da aplicacao
  ([ADR-0005](0005-deploy-da-aplicacao-fora-do-terraform.md)).
