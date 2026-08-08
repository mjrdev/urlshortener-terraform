# ADR 0014 — Endurecimento da pipeline em repositorio publico

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

O repositorio e publico. Isso muda duas premissas que os ADRs anteriores tinham
como implicitas:

1. **Artifacts de workflow sao baixaveis por qualquer pessoa, sem autenticacao.**
   O `terraform.yaml` publicava o plano salvo como artifact `tfplan` para o job de
   `apply` consumir. Um plano carrega em texto recuperavel (`terraform show`) os
   valores das variaveis `sensitive`, os ARNs com o id da conta e os ids de
   VPC/subnet/security group. Cinco planos ficaram publicos entre 2026-07-30 e
   2026-08-08 antes de expirarem pelo `retention-days: 5`.
2. **A superficie de ataque deixa de depender de quem tem acesso ao repositorio.**
   Com `AdministratorAccess` em `module.iam_terraform` e `apply` automatico em push
   na `main`, qualquer caminho que chegue a um commit na `main` — token vazado ou
   uma action de terceiro comprometida — resulta em controle total da conta AWS,
   sem intervencao humana.

A [ADR-0006](0006-autenticacao-da-ci-via-github-oidc.md) tinha registrado a politica
minima como divida consciente, com o argumento de que "uma policy incompleta quebra
o apply no meio". O argumento continua valido, mas deixou de superar o risco.

## Decisao

### O plano nunca sai do runner

Os jobs `plan` e `apply` do `terraform.yaml` foram fundidos em um job unico
(`Plan & Apply`), passando o `tfplan` pelo filesystem. O `apply` continua consumindo
o plano salvo — a garantia de aplicar exatamente o que foi planejado esta preservada —
mas o arquivo morre com a VM. O guard do `apply` segue sendo
`github.ref == 'refs/heads/main' && github.event_name == 'push'`, agora no step.

### `module.iam_terraform` com politica escopada

O `AdministratorAccess` foi substituido por 10 politicas no input `policies`, uma por
dominio (`network`, `ecr`, `ecs`, `elb`, `logs`, `autoscaling`,
`service-linked-roles`, `iam-project`, `iam-policies`, `state`).

O criterio e "so as acoes que os modulos em `modules/` realmente chamam". O escopo
vem do resource ARN onde o servico suporta resource-level (`ecr`, `logs`, `state`,
as duas de `iam`) e da lista de acoes onde nao suporta (`network`, `ecs`, `elb` —
ARNs de rede so existem depois da criacao).

Ausencias deliberadas: `ec2:RunInstances` e `ec2:CreateVolume` (fecha o uso classico
de conta comprometida para mineracao), `iam:*User*` e `iam:CreateAccessKey` (fecha
persistencia via credencial nova) e `s3:DeleteBucket` (um apply nao apaga o proprio
historico de state).

O id da conta entra por `data.aws_caller_identity.current`, nunca literal: o
repositorio e publico.

### Actions pinadas por SHA

`actions/checkout`, `aws-actions/configure-aws-credentials` e
`hashicorp/setup-terraform` passaram a ser referenciadas por SHA de commit, com a
tag no comentario. Tags git sao mutaveis: um mantenedor comprometido move a tag e o
codigo dele executa no job que carrega a credencial AWS. Foi o vetor do incidente
`tj-actions/changed-files` em marco de 2025. Um `.github/dependabot.yml` acompanha a
decisao — sem ele, pinar por SHA congela tambem as correcoes de seguranca.

Os providers Terraform ja estavam protegidos disso pelo `.terraform.lock.hcl`.

## Alternativas consideradas

- **Manter dois jobs e cifrar o artifact** — resolve o vazamento, mas guarda uma
  chave para gerenciar em troca de nada: nenhum consumidor do plano existe fora do
  proprio workflow.
- **`retention-days: 1`** — reduz a janela, nao o problema.
- **Ruleset na `main` e required reviewer como controle primario** — descartados como
  *primeira* linha, nao como praticas. Sao reversiveis por quem tem admin no
  repositorio, que e exatamente a identidade que um ataque comprometeria. A politica
  IAM nao e reversivel pelo lado do GitHub, por isso ela veio antes.
- **Permissions boundary nas roles criadas pela pipeline** — fecharia o escalation
  que resta (ver Consequencias), mas `modules/iam` nao suporta `condition` no input
  `policies`, e a boundary exige condicao. Fica como divida.
- **Role separada de plan, com `ReadOnlyAccess`** — o plan em PR nao deveria carregar
  credencial de escrita. Depende de ampliar `github_subjects_terraform`, hoje restrito
  a `ref:refs/heads/main`. Divida registrada.

## Consequencias

- **Servico novo exige acao nova em `iam.tf`.** Um `apply` que topa em acao faltando
  para com `AccessDenied` no meio. E o custo aceito da decisao, e o motivo de a
  primeira aplicacao ser feita localmente.
- **A primeira aplicacao roda local, nao pela pipeline.** A role modifica a si mesma:
  se o `apply` desanexar o `AdministratorAccess` antes de criar as politicas novas,
  ele perde permissao no meio do proprio apply. Rodar com credencial de fora da role
  (sessao local) elimina a corrida.
- **O escalation nao esta totalmente fechado.** `iam-project` permite
  `iam:AttachRolePolicy` nas roles com prefixo `${var.name}`, e nada impede anexar
  `AdministratorAccess` a uma delas. O ganho e de raio de explosao — nenhum recurso
  fora do projeto, nenhum usuario IAM, nenhuma access key — nao de impossibilidade.
  Fechar exige permissions boundary.
- **Limite da AWS: 10 politicas gerenciadas por role**, que e exatamente o numero
  atual. O proximo dominio exige agrupar politicas ou pedir aumento de quota.
- Os cinco planos que ficaram publicos expuseram id da conta, ARNs e ids de recursos
  de rede. **Nada disso e credencial** e, com OIDC, nao existe chave de longa duracao
  para rotacionar. Nao houve acao de resposta alem de parar de publicar.
