## 1. Permissoes da pipeline (primeiro, sozinho)

- [x] 1.1 Em `iam.tf`, consolidar as entradas `ecs`, `elb` e `autoscaling` de
      `module.iam_terraform` numa unica entrada `compute` com `resources = ["*"]`,
      preservando todas as acoes das tres e o comentario que explica por que o escopo vem
      da lista de acoes
- [x] 1.2 Adicionar a entrada `data-stores`: acoes de RDS (`CreateDBInstance`,
      `DeleteDBInstance`, `ModifyDBInstance`, `DescribeDBInstances`,
      `Create/Delete/DescribeDBSubnetGroups`, `AddTagsToResource`, `ListTagsForResource`,
      `RemoveTagsFromResource`) e de ElastiCache (`Create/Delete/Modify/DescribeCacheClusters`,
      `Create/Delete/DescribeCacheSubnetGroups`, `AddTagsToResource`, `ListTagsForResource`),
      com `resources` nos ARNs de `rds` e `elasticache` prefixados por `var.name`
- [x] 1.3 Adicionar a entrada `ssm`: `ssm:PutParameter`, `GetParameter`, `GetParameters`,
      `DeleteParameter`, `AddTagsToResource`, `ListTagsForResource`, mais `kms:Decrypt` e
      `kms:DescribeKey`; `resources` no prefixo `parameter/${var.name}/*` e no ARN de chave
      da conta. Nao incluir `ssm:DescribeParameters` (listagem, exigiria `"*"`)
- [x] 1.4 Confirmar que `module.iam_terraform` continua com no maximo 10 entradas em
      `policies` e rodar `terraform validate`
- [ ] 1.5 Aplicar so este passo (`terraform apply -target=module.iam_terraform`) antes de
      seguir — o resto do plano depende dele

## 2. Modulo `modules/ssm-parameter`

- [x] 2.1 Criar `modules/ssm-parameter/` com `main.tf`, `variables.tf`, `outputs.tf` e
      `versions.tf` (provider `>= 6.0`), recurso `aws_ssm_parameter.this`
- [x] 2.2 Inputs: `name`, `value` (sensitive), `type` (default `SecureString`),
      `description`, `tags`; aplicar `merge({ Name = var.name }, var.tags)`
- [x] 2.3 Outputs: `arn` e `name`; nunca expor `value`
- [x] 2.4 Gerar `modules/ssm-parameter/README.md` com terraform-docs

## 3. Modulo `modules/rds`

- [x] 3.1 Criar `modules/rds/` com `aws_db_subnet_group.this` e `aws_db_instance.this`
- [x] 3.2 Inputs com defaults de custo minimo: `instance_class = "db.t4g.micro"`,
      `allocated_storage = 20`, `storage_type = "gp3"`, `engine = "postgres"`,
      `engine_version = "17"`, `multi_az = false`, `backup_retention_period = 1`,
      `performance_insights_enabled = false`, `skip_final_snapshot = true`,
      `deletion_protection = false`, `publicly_accessible = false`,
      `storage_encrypted = true`, `auto_minor_version_upgrade = true`; mais `name`,
      `subnets`, `security_group_ids`, `db_name`, `username`, `password` (sensitive),
      `port`, `tags`
- [x] 3.3 Outputs: `address` (host puro), `port`, `db_name`, `endpoint`, `arn`,
      `identifier`; nada com a senha
- [x] 3.4 Gerar `modules/rds/README.md` com terraform-docs

## 4. Modulo `modules/elasticache`

- [x] 4.1 Criar `modules/elasticache/` com `aws_elasticache_subnet_group.this` e
      `aws_elasticache_cluster.this`
- [x] 4.2 Inputs: `name`, `subnets`, `security_group_ids`, `engine` (default `valkey`),
      `engine_version`, `node_type` (default `cache.t4g.micro`), `num_cache_nodes`
      (default 1), `port` (default 6379), `tags`
- [x] 4.3 Outputs: `address` (de `cache_nodes[0].address`), `port`, `arn`, `cluster_id`
- [x] 4.4 Gerar `modules/elasticache/README.md` com terraform-docs

## 5. Fiacao na raiz

- [x] 5.1 Criar `datastores.tf` com `module.sg_rds` e `module.sg_redis`, cada um com uma
      regra de ingress cuja origem e `module.sg_ecs_tasks.id` na porta do servico e egress
      apenas dentro da VPC
- [x] 5.2 Em `datastores.tf`, gerar `random_password.db` e `random_password.jwt`
      (`special = false` na senha do banco para evitar caractere problematico em DSN) e
      instanciar `module.ssm_db_password` e `module.ssm_jwt_secret` com os nomes
      `/${var.name}/db-password` e `/${var.name}/jwt-secret`
- [x] 5.3 Instanciar `module.rds` e `module.redis` nas `module.vpc.private_subnet_ids`,
      com os security groups do passo 5.1
- [x] 5.4 Declarar o provider `random` em `versions.tf` (`hashicorp/random ~> 3.0`) na raiz
- [x] 5.5 Em `app.tf`, passar em `environment` do `module.ecs_app`: `PORT`, `DB_HOST`,
      `DB_PORT`, `DB_USER`, `DB_NAME`, `DB_SSLMODE = "require"`, `REDIS_URL` (host puro),
      `REDIS_PORT`, `REDIS_TLS = "false"`; e em `secrets`: `DB_PASSWORD` e `JWT_SECRET`
      apontando para os ARNs dos parametros
- [x] 5.6 Acrescentar em `variables.tf` e em `environments/prod.tfvars`,
      `environments/dev.tfvars` e `environments/example.tfvars` as variaveis novas
      (`db_instance_class`, `db_allocated_storage`, `db_engine_version`, `db_name`,
      `db_username`, `redis_node_type`, `redis_engine_version`), com os defaults baratos
- [x] 5.7 Acrescentar em `outputs.tf`: `rds_endpoint`, `rds_db_name` e `redis_address`
      (nenhum segredo)

## 6. Pipeline e documentacao

- [x] 6.1 Acrescentar `-target=module.rds`, `-target=module.redis`, `-target=module.sg_rds`,
      `-target=module.sg_redis`, `-target=module.ssm_db_password` e
      `-target=module.ssm_jwt_secret` em `.github/workflows/terraform-destroy.yaml`, antes
      dos targets de rede
- [x] 6.2 Escrever `docs/adr/0015-dados-gerenciados-na-vpc.md` registrando Postgres e Redis
      gerenciados, o criterio de custo minimo e a escolha de Parameter Store sobre Secrets
      Manager; indexar em `docs/adr/README.md`
- [x] 6.3 Atualizar `README.md` (diagrama, tabela de modulos, tabela de arquivos com
      `datastores.tf`) e `CLAUDE.md` (bullet sobre onde vivem os dados e o teto de
      politicas ja consolidado)
- [x] 6.4 Regenerar as tabelas do README raiz e dos modulos novos com terraform-docs

## 7. Verificacao

- [x] 7.1 `terraform fmt -recursive` e `terraform validate` limpos
- [ ] 7.2 `terraform plan -var-file=environments/prod.tfvars` mostrando so os recursos
      novos, a revisao nova da task definition e as politicas consolidadas — nenhum toque
      em VPC, ALB ou no servico ECS
- [ ] 7.3 Apply e conferencia: instancia RDS `available`, cluster de cache disponivel,
      parametros presentes com `type = SecureString`
- [ ] 7.4 Disparar a pipeline do app e confirmar que a task nova sobe com a revisao que
      carrega `environment` e `secrets`, que o alvo do ALB fica `healthy` e que o log do
      container mostra a conexao com banco e cache
- [x] 7.5 Registrar como proximo passo (fora desta mudanca) a execucao do `cmd/migrate`:
      sem schema, as rotas de API respondem erro mesmo com a task saudavel
