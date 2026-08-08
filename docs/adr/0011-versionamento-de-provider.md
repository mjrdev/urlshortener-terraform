# ADR 0011 — Versao do provider fixada no root, range aberto nos modulos

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

Cada modulo local tem seu `versions.tf` com `required_providers`. Se todos
fixassem a versao, uma atualizacao do provider viraria uma edicao em oito arquivos
— e qualquer divergencia entre eles resultaria em conflito de constraints que
impede o `init`.

## Decisao

Divisao de papeis: **o root decide a versao; os modulos declaram compatibilidade.**

- `versions.tf` da raiz: `aws ~> 6.0` e `required_version >= 1.0.0`.
- `versions.tf` de cada modulo: `aws >= 6.0`, range aberto de proposito, dizendo
  apenas "funciono da 6 em diante".
- `.terraform.lock.hcl` versionado — e ele que trava a versao exata usada em plan e
  apply, na maquina e na CI.

A versao do Terraform na CI vem de `vars.TF_VERSION`, nao esta fixada no codigo.

## Alternativas consideradas

- **Pin em todos os modulos** — atualizacao vira mudanca em N arquivos, com risco
  de constraints incompativeis entre eles.
- **Range aberto tambem no root** — sem `~>`, um major novo do provider entraria
  sozinho na primeira vez que o lock fosse regenerado.
- **Nao versionar o lock file** — CI e maquina local poderiam resolver versoes
  diferentes do provider para o mesmo commit.

## Consequencias

- Atualizar o provider e mexer em um lugar (`versions.tf` da raiz) e rodar
  `terraform init -upgrade` para regenerar o lock.
- Os modulos nao sao independentemente versionados; sao locais e sempre resolvidos
  no contexto do root ([ADR-0003](0003-root-composicional-com-modulos-locais.md)).
  Se um dia forem publicados, o range aberto e o comportamento certo para um modulo
  reutilizavel.
- **O range aberto nos modulos nao oferece protecao por si so** — quem consumir um
  destes modulos a partir de outro root herda a decisao daquele root, nao desta.
- `required_version >= 1.0.0` e permissivo; a versao efetiva na CI e a de
  `vars.TF_VERSION`, o que significa que **a versao do Terraform nao esta
  registrada no repositorio**. Divergencia entre a maquina local e a CI e possivel.
