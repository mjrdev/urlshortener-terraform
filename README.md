# urlshortener — infraestrutura

Terraform da infraestrutura do encurtador de URLs na AWS: VPC com subnets publicas
e privadas, ALB internet-facing, aplicacao em ECS Fargate, repositorio ECR e as
roles do GitHub Actions via OIDC (sem access key de longa duracao).

```
                   internet
                      │
                  ┌───▼────┐   subnets publicas
                  │  ALB   │   :80 → 301 :443 (com certificado)
                  └───┬────┘
                      │ target group (target_type = ip)
        ┌─────────────▼─────────────┐
        │      ECS Fargate          │   subnets privadas
        │       ┌──────────┐        │
        │       │ app      │        │   1 a 4 tasks (autoscaling por CPU)
        │       │ :8080    │        │
        │       └────┬─────┘        │
        └────────────┼──────────────┘
                     │ NAT gateway
             ECR / CloudWatch Logs / SSM
```

## Layout

| Arquivo | Conteudo |
|---|---|
| `versions.tf` | versao do Terraform, providers e backend S3 (parcial) |
| `providers.tf` | provider AWS e `default_tags` |
| `network.tf` | VPC |
| `ecr.tf` | repositorio de imagens |
| `iam.tf` | provider OIDC e as roles do GitHub Actions |
| `app.tf` | security groups, ALB e servico ECS da aplicacao |
| `moved.tf` | renomeacoes de modulo pendentes de apply (temporario) |
| `environments/` | tfvars e backend config por ambiente |
| `modules/` | modulos reusaveis, cada um com seu README |
| `docs/adr/` | [decisoes de arquitetura](docs/adr/README.md) e o porque de cada uma |

Terraform carrega todos os `*.tf` do diretorio como um arquivo so — a divisao acima
e organizacional e nao afeta o state.

## Modulos

| Modulo | Para que serve |
|---|---|
| [vpc](modules/vpc) | VPC, subnets publicas/privadas, IGW e NAT |
| [security-group](modules/security-group) | security group com regras por mapa |
| [elb](modules/elb) | ALB, target group e listeners |
| [ecs](modules/ecs) | cluster/servico Fargate, task definition, roles e autoscaling |
| [ecr](modules/ecr) | repositorio de imagens com scan on push |
| [github-oidc](modules/github-oidc) | provider OIDC do GitHub (um por conta) |
| [iam](modules/iam) | role com trust policy e policies parametrizadas |

## Pre-requisitos

- Terraform >= 1.0.0
- Credencial AWS com permissao no bucket de state `mjr-terraform` (us-east-1)
- As duas variaveis sensiveis, exportadas ou num tfvars local nao versionado:

  ```bash
  export TF_VAR_app_repository="owner@ownerid/repo@repoid"
  export TF_VAR_terraform_repository="owner@ownerid/repo@repoid"
  ```

  O formato e o do claim `sub` do OIDC do GitHub; os IDs numericos protegem contra
  rename do repositorio. Da para confirmar o valor exato no CloudTrail, no evento
  `AssumeRoleWithWebIdentity`.

## Uso

O backend e **parcial**: a `key` do state vem do arquivo do ambiente, entao o `init`
precisa sempre do `-backend-config`.

```bash
# prod
terraform init -input=false -backend-config=environments/prod.backend.hcl
terraform plan  -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars

# trocar de ambiente exige reconfigurar o backend
terraform init -input=false -reconfigure -backend-config=environments/dev.backend.hcl
terraform plan -var-file=environments/dev.tfvars
```

Ambiente novo: copie `environments/example.tfvars`, crie o `.backend.hcl`
correspondente com uma `key` propria e rode o `init` apontando para ele.

## Configuracao versus segredo

`environments/*.tfvars` e versionado de proposito e guarda so configuracao (CIDR,
sizing, portas). O que e `sensitive` — `app_repository` e `terraform_repository` —
fica nos secrets do GitHub e chega como `TF_VAR_*`. O `terraform.tfvars` na raiz
continua ignorado pelo git e serve para sobrescritas locais.

## CI

- **`terraform.yaml`** — em PR e push na main: `fmt -check`, `validate`, `plan` e,
  so em push na main, `apply` do plano salvo. `plan` e `apply` ficam no mesmo job:
  o `tfplan` nao vira artifact porque exporia valores sensitive a quem baixasse.
- **`terraform-destroy.yaml`** — `workflow_dispatch` com confirmacao digitada.
  Destroi por `-target`, deixando de fora `module.github_oidc` e
  `module.iam_terraform`: os dois tem `prevent_destroy` e derrubar qualquer um
  quebraria o proprio acesso da pipeline.

Ambos assumem a role de infraestrutura por OIDC (`secrets.ROLE_ARN`).

## Documentacao dos modulos

As tabelas de inputs/outputs dos READMEs sao geradas pelo
[terraform-docs](https://terraform-docs.io) e injetadas entre os marcadores
`BEGIN_TF_DOCS` / `END_TF_DOCS`. Depois de mexer em variaveis ou outputs:

```bash
terraform-docs markdown table --config .terraform-docs.yml modules/<modulo>
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | ~> 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| alb | ./modules/elb | n/a |
| ecr | ./modules/ecr | n/a |
| ecs\_app | ./modules/ecs | n/a |
| github\_oidc | ./modules/github-oidc | n/a |
| iam\_app | ./modules/iam | n/a |
| iam\_terraform | ./modules/iam | n/a |
| sg\_alb | ./modules/security-group | n/a |
| sg\_ecs\_tasks | ./modules/security-group | n/a |
| vpc | ./modules/vpc | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| app\_repository | Repo da aplicacao, formato owner@ownerid/repo@repoid. | `string` | n/a | yes |
| name | Prefixo de todos os recursos do stack. Distingue os ambientes entre si. | `string` | n/a | yes |
| terraform\_repository | Repo da pipeline de infraestrutura, formato owner@ownerid/repo@repoid. | `string` | n/a | yes |
| vpc\_cidr | CIDR da VPC. Precisa comportar 2 x subnet\_count faixas /24. | `string` | n/a | yes |
| app\_cpu | Unidades de CPU da task (1024 = 1 vCPU). | `number` | `256` | no |
| app\_desired\_count | Quantidade de tasks em regime normal, tambem o piso do autoscaling. | `number` | `1` | no |
| app\_health\_check\_path | Rota usada pelo ALB para checar a saude das tasks ECS. | `string` | `"/health"` | no |
| app\_image\_tag | Tag da imagem no ECR usada na primeira revisao da task definition. Os deploys<br/>seguintes sao feitos pela pipeline da aplicacao, que publica novas revisoes<br/>sem passar pelo Terraform. | `string` | `"latest"` | no |
| app\_max\_capacity | Teto de tasks do autoscaling. | `number` | `4` | no |
| app\_memory | Memoria da task em MiB. | `number` | `512` | no |
| app\_port | Porta em que o container do encurtador escuta. Alvo do target group do ALB. | `number` | `8080` | no |
| github\_subjects | Refs autorizadas a assumir a role, sufixo do claim `sub` do OIDC.<br/>Exemplos: "ref:refs/heads/main", "environment:prod", "pull\_request". | `list(string)` | <pre>[<br/>  "ref:refs/heads/main"<br/>]</pre> | no |
| github\_subjects\_terraform | Refs autorizadas na role de infraestrutura. | `list(string)` | <pre>[<br/>  "ref:refs/heads/main"<br/>]</pre> | no |
| region | Regiao AWS do stack. | `string` | `"us-east-1"` | no |
| single\_nat\_gateway | Com true, um unico NAT gateway atende todas as subnets privadas: mais barato e<br/>ponto unico de falha. Com false, sai um NAT por AZ. | `bool` | `true` | no |
| subnet\_count | Quantidade de subnets por tier: N publicas e N privadas. | `number` | `3` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb\_dns\_name | DNS publico do ALB — ponto de entrada da aplicacao |
| alb\_target\_group\_arn | Target group a ser referenciado pelo aws\_ecs\_service |
| ecr\_repository\_url | URL do repositorio ECR — destino do docker push |
| ecs\_cluster\_name | Cluster ECS — usado no aws ecs update-service do deploy |
| ecs\_container\_name | Nome do container na task definition |
| ecs\_log\_group\_name | Log group com a saida dos containers |
| ecs\_service\_name | Servico ECS do encurtador |
| ecs\_task\_definition\_family | Familia da task definition — base das revisoes publicadas pela pipeline |
| iam\_app\_role\_arn | Role assumida pelo GitHub Actions da aplicacao |
| terraform\_role\_arn | Role assumida pela pipeline de infraestrutura |
| vpc\_id | ID da VPC |
<!-- END_TF_DOCS -->
