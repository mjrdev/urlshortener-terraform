# ADR 0007 — `prevent_destroy` como input de modulo, via recursos gemeos

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

O provider OIDC e a role `iam_terraform` sao o acesso da propria pipeline a conta:
destrui-los deixa a CI sem como se autenticar e exige intervencao manual para
recriar. Eles precisam de `lifecycle { prevent_destroy = true }`.

O problema e que `prevent_destroy` **nao aceita expressao** — o bloco `lifecycle`
so admite literais, entao nao da para escrever `prevent_destroy = var.protegido`.
Como os mesmos modulos (`modules/iam`, `modules/github-oidc`) tambem criam recursos
descartaveis, marcar o recurso no codigo protegeria todas as instancias, inclusive
a role da aplicacao, que precisa ser destruivel pelo workflow de destroy.

## Decisao

Expor `prevent_destroy` como variavel do modulo e implementa-la com **dois recursos
gemeos mutuamente exclusivos**, selecionados por `count`:

```hcl
resource "aws_iam_role" "this" {      # sem protecao
  count = var.prevent_destroy ? 0 : 1
  ...
}

resource "aws_iam_role" "protected" { # identico, com lifecycle
  count = var.prevent_destroy ? 1 : 0
  ...
  lifecycle { prevent_destroy = true }
}
```

O resto do modulo nunca referencia os recursos direto: le de locals que resolvem
qual dos dois existe com `one(concat(aws_iam_role.this[*].arn, aws_iam_role.protected[*].arn))`.
Mesmo padrao em `modules/github-oidc`.

Hoje usam `prevent_destroy = true`: `module.github_oidc` e `module.iam_terraform`.
`module.iam_app` fica sem protecao, de proposito.

## Alternativas consideradas

- **`prevent_destroy` fixo no recurso** — protegeria tambem `iam_app`, que precisa
  entrar no destroy seletivo.
- **Nao usar `prevent_destroy` e confiar na revisao do plan** — o modo de falha
  aqui e justamente o apply automatico da CI, que nao tem ninguem lendo o plan.
- **Mover os recursos protegidos para um root module separado** — isolamento real
  (state proprio, nunca alcancado por um destroy daqui), ao custo de mais um state
  e de cruzar os outputs entre dois roots. E o caminho se a protecao atual se
  mostrar insuficiente.

## Consequencias

- **Alternar a flag recria o recurso.** Ligar ou desligar `prevent_destroy` muda o
  endereco no state (`this[0]` ↔ `protected[0]`), entao o Terraform destroi um e
  cria outro — no caso da role da pipeline, com janela de indisponibilidade e ARN
  novo. Nao mude sem intencao; se precisar, faca junto de um bloco `moved`.
- `prevent_destroy` bloqueia o **plan inteiro**, nao so aquele recurso: um
  `terraform destroy` sem `-target` falha antes de destruir qualquer coisa. Dai o
  workflow de destroy usar `-target`
  ([ADR-0008](0008-destroy-seletivo-por-target.md)).
- Os dois blocos precisam ser mantidos **identicos** a cada campo novo; divergencia
  entre eles so aparece quando alguem vira a flag.
- A protecao vale so para o Terraform. Apagar a role pelo console AWS continua
  possivel.
