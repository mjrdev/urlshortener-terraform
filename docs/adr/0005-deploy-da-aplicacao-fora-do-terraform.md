# ADR 0005 — O Terraform nao faz deploy da aplicacao

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

O codigo da aplicacao vive em outro repositorio, com pipeline propria que builda a
imagem e a publica no ECR. O Terraform tambem declara a task definition e o
`desired_count` do servico ECS. Se os dois lados escreverem nos mesmos campos, cada
`terraform apply` reverte o ultimo deploy da aplicacao para a tag registrada no
state, e cada evento de autoscaling vira drift no proximo plan.

## Decisao

Fronteira explicita: **o Terraform e dono da forma do servico; a pipeline da
aplicacao e dona da versao que roda nele.**

Em `modules/ecs`, o `aws_ecs_service` carrega:

```hcl
lifecycle {
  ignore_changes = [task_definition, desired_count]
}
```

- Novas revisoes de task definition sao publicadas pela pipeline do app, que
  atualiza o servico.
- `desired_count` e movido pelo Application Auto Scaling.
- `var.app_image_tag` so tem efeito na **primeira** revisao criada; depois disso e
  ignorado, e nao adianta mudar a tag no tfvars para promover uma versao.

Tudo o mais do servico — rede, security groups, roles, log group, autoscaling,
circuit breaker, target group — continua sendo do Terraform.

## Alternativas consideradas

- **Terraform como responsavel pelo deploy** (`app_image_tag` sendo a fonte da
  verdade) — deploy de aplicacao passaria a exigir um apply de infraestrutura, com
  credenciais de infraestrutura, num repositorio que o time da aplicacao nao mexe.
  Acopla a cadencia de deploy a cadencia da infra.
- **`ignore_changes` so em `desired_count`** — resolve o autoscaling mas nao a
  task definition; o proximo apply ainda faria rollback da imagem em producao.
- **Task definition fora do Terraform** (so o servico aqui) — tira do Terraform a
  definicao de CPU, memoria, roles e logs, que sao decisoes de infraestrutura.

## Consequencias

- `terraform apply` e seguro a qualquer momento: nao reverte a versao em producao
  nem atropela o autoscaling.
- **A task definition no state fica desatualizada de proposito.** Ler
  `aws_ecs_task_definition.this` no Terraform nao diz o que esta rodando; a fonte
  e o servico ECS na AWS.
- Mudanca em CPU, memoria, variaveis de ambiente ou secrets cria uma revisao nova
  pelo Terraform, mas **o servico so passa a usa-la no proximo deploy da
  aplicacao**, porque `task_definition` esta em `ignore_changes`. Para aplicar na
  hora, e preciso forcar o update do servico fora do Terraform.
- A role `module.iam_app` existe exatamente para essa pipeline e tem permissao de
  push no ECR — nada de infraestrutura
  ([ADR-0006](0006-autenticacao-da-ci-via-github-oidc.md)).
