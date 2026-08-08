# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que e

Terraform da infraestrutura AWS de um encurtador de URLs: VPC (subnets publicas/privadas + NAT),
ALB internet-facing, servicos ECS Fargate, ECR e as roles do GitHub Actions via OIDC.
O codigo da aplicacao vive em outro repositorio — aqui so ha infraestrutura.

Comentarios, descricoes de variaveis e documentacao sao escritos em **portugues sem acentos**.
Mantenha esse padrao ao editar.

## Comandos

O backend S3 e **parcial**: a `key` do state vem de `environments/<env>.backend.hcl`, entao todo
`init` precisa de `-backend-config`, e trocar de ambiente exige `-reconfigure`.

```bash
terraform init -input=false -backend-config=environments/prod.backend.hcl
terraform plan  -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars

# trocar para dev
terraform init -input=false -reconfigure -backend-config=environments/dev.backend.hcl
```

Antes de commitar (a CI roda os mesmos passos):

```bash
terraform fmt -recursive
terraform validate            # exige init com backend-config
```

Duas variaveis `sensitive` nao ficam em tfvars versionado; exporte-as localmente
(na CI vem de `secrets.APP_REPOSITORY` / `secrets.TERRAFORM_REPOSITORY`):

```bash
export TF_VAR_app_repository="owner@ownerid/repo@repoid"
export TF_VAR_terraform_repository="owner@ownerid/repo@repoid"
```

Depois de mexer em variaveis ou outputs de qualquer modulo, regenere os READMEs
(as tabelas sao injetadas entre `BEGIN_TF_DOCS` / `END_TF_DOCS`; o texto escrito a mao fora
dos marcadores e preservado):

```bash
terraform-docs markdown table --recursive --recursive-path modules --config .terraform-docs.yml .
```

## Arquitetura

O **porque** das decisoes estruturais esta em `docs/adr/` (indice em
`docs/adr/README.md`). Mudanca de topologia, de fronteira com a pipeline ou de
estrategia de state deve vir acompanhada de um ADR novo ou atualizado.

Root module composicional: os `.tf` da raiz so instanciam modulos locais e ligam um no outro —
nenhum `resource` mora na raiz. A divisao em arquivos (`network.tf`, `ecr.tf`, `iam.tf`,
`app.tf`, `sandbox.tf`) e puramente organizacional; Terraform le tudo como um arquivo so.

Fluxo: internet → ALB (subnets publicas, `target_type = "ip"` porque `awsvpc` registra os ENIs
das tasks) → tasks ECS nas subnets privadas → saida para ECR/CloudWatch pelo NAT.
`module.ecs_nginx` (em `sandbox.tf`) e um servico descartavel que reusa o cluster de
`module.ecs_app` via `cluster_arn`, sem target group — o arquivo inteiro pode ser apagado.

Pontos que se aprendem lendo varios arquivos:

- **O Terraform nao faz deploy da aplicacao.** `modules/ecs` tem
  `ignore_changes = [task_definition, desired_count]`: novas revisoes vem da pipeline do app e o
  `desired_count` e do autoscaling. `app_image_tag` so vale para a primeira revisao.
- **`prevent_destroy` e um input de modulo**, nao so um `lifecycle`. Em `modules/iam` e
  `modules/github-oidc` a flag alterna entre dois recursos gemeos (`this` sem protecao,
  `protected` com `lifecycle { prevent_destroy = true }`), e os outputs saem de um `one(concat(...))`.
  Ligar/desligar a flag **recria a role/provider** — nao mude sem intencao.
- **`module.github_oidc` e `module.iam_terraform` sao o acesso da propria pipeline.** Por isso o
  workflow de destroy usa `-target` explicito em cada modulo e deixa esses dois de fora.
- **`modules/ecs` cria o cluster so quando `cluster_arn` e null** (`count`), e carrega blocos
  `moved` para o endereco `[0]`. Varios servicos compartilham cluster passando `cluster_arn`.
- **Security groups por mapa**: `modules/security-group` recebe `ingress_rules`/`egress_rules`
  como `map(object)`. A chave do mapa e a identidade da regra no state — renomear recria a regra.
  Uma validacao exige exatamente uma origem por regra (cidr_ipv4 / cidr_ipv6 / prefix_list_id /
  referenced_security_group_id).
- **`versions.tf` dos modulos usa range aberto (`>= 6.0`)** de proposito; quem fixa a versao do
  provider e o root (`~> 6.0`).
- **`moved.tf` na raiz e temporario** — renomeacoes de modulo pendentes de apply. Apagar depois
  que rodar em todos os ambientes com state (hoje so prod).

## Convencoes

- Modulo local = pasta em `modules/<nome>` com `main.tf`, `variables.tf`, `outputs.tf`,
  `versions.tf` e `README.md` gerado pelo terraform-docs.
- Nomes de bloco de modulo usam underscore (`ecs_app`, `sg_alb`); recursos dentro dos modulos
  chamam-se `this`.
- Todo recurso nomeado a partir de `var.name`; tags comuns vem de `default_tags` no provider,
  e os modulos ainda fazem `merge({ Name = var.name }, var.tags)`.
- `environments/*.tfvars` e versionado e guarda so configuracao (CIDR, sizing, portas).
  `terraform.tfvars` na raiz e ignorado pelo git e serve para sobrescritas locais.
  Ambiente novo: copie `environments/example.tfvars` e crie o `.backend.hcl` com uma `key` propria.

## CI

- `.github/workflows/terraform.yaml` — PR e push na main: `fmt -check`, `validate`, `plan`;
  `apply` do plano salvo so em push na main. `TF_ENV: prod` fixo. `plan` e `apply` moram no
  mesmo job e o `tfplan` nunca sai do runner: como artifact, o plano vazaria os valores
  sensitive e os ARNs com o id da conta para qualquer um que baixasse o run.
- `.github/workflows/terraform-destroy.yaml` — `workflow_dispatch` com a palavra `destroy`
  digitada; destroi por `-target`. Ao adicionar um modulo novo que deve ser destruivel,
  acrescente o `-target` correspondente ali.
