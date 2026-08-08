# ADR 0002 — Backend S3 parcial com uma key por ambiente

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

O state comecou com a `key` fixa no bloco `backend "s3"`, o que amarra o repositorio
a um unico state — na pratica, a um unico ambiente. Assim que apareceu a
necessidade de um `dev` separado de `prod`, era preciso escolher como separar os
states sem duplicar codigo e sem migrar o state de prod que ja existia.

## Decisao

Manter o backend S3 **parcial** em `versions.tf`: `bucket` e `region` ficam no
codigo, a `key` vem de `environments/<env>.backend.hcl` no `init`.

```bash
terraform init -input=false -backend-config=environments/prod.backend.hcl
terraform init -input=false -reconfigure -backend-config=environments/dev.backend.hcl
```

A key de prod continua `url-shortener/terraform.tfstate` — exatamente o valor que
estava fixo no bloco antes da mudanca, para que o `init` nao dispare migracao de
state. Dev usa `url-shortener/dev/terraform.tfstate`. A configuracao nao sensivel
de cada ambiente vive em `environments/<env>.tfvars`, versionada; `terraform.tfvars`
na raiz e ignorado pelo git e serve so para sobrescritas locais.

## Alternativas consideradas

- **Terraform workspaces** — separa states com um comando so, mas todos os
  ambientes passam a compartilhar o mesmo `.tfvars` e a variacao vira
  `terraform.workspace` espalhado por condicionais no codigo. Com backend parcial
  a diferenca entre ambientes fica declarada num arquivo por ambiente.
- **Um diretorio raiz por ambiente** (`envs/prod/`, `envs/dev/`) — isolamento
  maior, ao custo de duplicar a composicao dos modulos em cada pasta e ter que
  replicar toda mudanca estrutural N vezes.
- **Key fixa e uma conta AWS por ambiente** — isolamento ideal, mas fora de
  escopo para o tamanho atual do projeto.

## Consequencias

- **Todo `init` precisa de `-backend-config`**; sem ele o Terraform pergunta a key
  interativamente (ou falha com `-input=false`, como na CI).
- **Trocar de ambiente exige `-reconfigure`**, senao o Terraform reaproveita a
  configuracao do backend em cache no `.terraform/` e opera no state errado.
- O par `plan`/`apply` sempre carrega dois arquivos do mesmo ambiente
  (`-backend-config` e `-var-file`). Misturar os dois — key de dev com tfvars de
  prod — e um erro que o Terraform nao detecta.
- Nao ha travamento por DynamoDB configurado; o lock depende do lock nativo do S3.
  Com um unico operador e a CI serializada isso basta hoje, mas e o primeiro
  ponto a revisitar quando mais gente aplicar.
- A CI fixa `TF_ENV: prod` ([ADR-0006](0006-autenticacao-da-ci-via-github-oidc.md));
  dev e, por enquanto, um ambiente aplicado localmente.
