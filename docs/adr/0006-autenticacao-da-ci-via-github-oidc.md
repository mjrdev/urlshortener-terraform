# ADR 0006 — Autenticacao da CI na AWS via GitHub OIDC

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

Dois repositorios precisam de acesso a esta conta AWS: o da aplicacao, para dar
push de imagem no ECR, e este, para rodar `plan`/`apply`. A saida obvia — criar um
usuario IAM e guardar `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` nos secrets do
GitHub — cria credenciais de longa duracao que ninguem rotaciona e que vazam
inteiras se um secret vazar.

## Decisao

Federacao OIDC entre GitHub Actions e IAM. Nenhuma credencial estatica.

- `module.github_oidc` cria o `aws_iam_openid_connect_provider` para
  `token.actions.githubusercontent.com`, com `client_id_list = ["sts.amazonaws.com"]`.
  E **unico por conta AWS**, por isso vive num modulo separado instanciado uma
  vez so. Sem `thumbprint_list`: a AWS valida o certificado do GitHub pelas CAs
  raiz dela.
- Uma role por repositorio, nao uma role compartilhada:
  - `module.iam_app` — push/pull no ECR, com `resources` no ARN do repositorio.
  - `module.iam_terraform` — a role da propria pipeline de infraestrutura. Nasceu
    com `AdministratorAccess`; hoje usa politica escopada por dominio
    ([ADR-0014](0014-endurecimento-da-pipeline-em-repo-publico.md)).
- As trust policies saem de `local.github_actions_trust`, gerado por um `for` sobre
  `local.github_repos`, para nao duplicar o bloco a cada repositorio novo. Cada uma
  exige `aud = sts.amazonaws.com` e casa o `sub` com
  `repo:<owner@ownerid/repo@repoid>:<subject>`.
- O identificador do repositorio usa o formato **`owner@ownerid/repo@repoid`**: os
  IDs numericos fazem a condicao continuar valida (e continuar restrita) mesmo se
  o repositorio for renomeado, e impedem que outra pessoa reivindique o nome
  antigo. As variaveis `app_repository` e `terraform_repository` sao `sensitive`,
  ficam fora dos tfvars versionados e vem de
  `secrets.APP_REPOSITORY` / `secrets.TERRAFORM_REPOSITORY`.
- Os workflows pedem `permissions: id-token: write` e usam
  `aws-actions/configure-aws-credentials` com `role-to-assume`, pinada por SHA
  ([ADR-0014](0014-endurecimento-da-pipeline-em-repo-publico.md)).

## Alternativas consideradas

- **Usuario IAM com access key nos secrets** — credencial permanente, sem escopo
  por repositorio ou por branch, e rotacao manual.
- **Uma role unica para os dois repositorios** — o repositorio da aplicacao
  herdaria poder de mexer em toda a infraestrutura.
- **Role da infraestrutura com politica minima em vez de `AdministratorAccess`** —
  correto em principio, mas o conjunto de acoes cresce a cada servico novo e uma
  policy incompleta quebra o apply no meio. Ficou como divida conhecida ate o
  repositorio virar publico, quando o risco passou a superar o custo:
  [ADR-0014](0014-endurecimento-da-pipeline-em-repo-publico.md) fez a troca e
  aceitou esse custo.

## Consequencias

- Nao existe credencial AWS de longa duracao ligada a este projeto; os tokens sao
  emitidos por execucao e expiram sozinhos.
- **O escopo vai ate a branch**: `github_subjects` e `github_subjects_terraform`
  usam `["ref:refs/heads/main"]`, entao um workflow rodando em branch de feature ou
  em PR nao assume a role. Ampliar (ou apertar para `environment:prod`) e mudanca
  nessas variaveis — e cada valor acrescentado ali e uma porta a mais.
- Comprometer o repositorio de infraestrutura da acesso de escrita a infraestrutura.
  Com a politica escopada de [ADR-0014](0014-endurecimento-da-pipeline-em-repo-publico.md)
  o alcance para no prefixo `${var.name}`, mas nao vira inofensivo. E o motivo de essa
  role e o provider OIDC serem protegidos
  ([ADR-0007](0007-prevent-destroy-como-input-de-modulo.md)) e ficarem fora do
  destroy ([ADR-0008](0008-destroy-seletivo-por-target.md)).
- Rodar a CI num fork ou renomear o repositorio sem atualizar o secret quebra a
  autenticacao com `AccessDenied` na hora do assume — nao no Terraform.
- Localmente, as duas variaveis `sensitive` precisam ser exportadas a mao
  (`TF_VAR_app_repository`, `TF_VAR_terraform_repository`), senao o plan pede input.
