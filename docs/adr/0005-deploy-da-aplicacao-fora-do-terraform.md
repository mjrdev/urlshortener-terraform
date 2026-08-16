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

## Como a pipeline do app promove uma versao

Roda no repositorio da aplicacao, assumindo por OIDC a role do output
`iam_app_role_arn` (`module.iam_app`):

1. Build e push da imagem no ECR **com o SHA do commit como tag**. `latest` pode
   continuar existindo, mas o deploy aponta para o SHA: e o que torna a revisao
   rastreavel e o rollback trivial (reapontar para a revisao anterior).
2. `aws ecs describe-task-definition --task-definition <family>` — pega a revisao
   ativa como base.
3. Troca `containerDefinitions[].image` do container `<container_name>` e registra
   a revisao nova com `aws ecs register-task-definition`.
4. `aws ecs update-service --cluster <cluster> --service <service>
   --task-definition <revisao nova>`.
5. `aws ecs wait services-stable`. Se a task nova nao subir, o
   `deployment_circuit_breaker` (`rollback = true`) devolve a revisao anterior
   sozinho.

Os nomes de cluster, servico, familia e container saem dos outputs do root:
`ecs_cluster_name`, `ecs_service_name`, `ecs_task_definition_family`,
`ecs_container_name` e `ecr_repository_url`.

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
- A role `module.iam_app` existe exatamente para essa pipeline: push no ECR mais o
  minimo de ECS para registrar a revisao e atualizar o servico — nada de
  infraestrutura ([ADR-0006](0006-autenticacao-da-ci-via-github-oidc.md)).
- **`module.iam_app` e a fronteira de permissao desse fluxo.** Como em
  `iam_terraform`, a politica lista so as acoes que o deploy realmente chama:
  mudanca no fluxo (blue/green pelo CodeDeploy, leitura de segredos, ECS Exec)
  exige acao nova em `iam.tf`, senao a pipeline do app para com `AccessDenied`.
