# ADR 0003 — Root module composicional com modulos locais proprios

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

A infraestrutura comecou como um `main.tf` unico na raiz misturando recursos soltos
e chamadas de modulo. Conforme VPC, ECR, IAM, ALB e ECS foram entrando, o arquivo
deixou de caber na cabeca e nao havia fronteira clara entre "o que este projeto
provisiona" e "como cada peca e construida".

## Decisao

A raiz e **puramente composicional**: nenhum `resource` mora nela. Os `.tf` da raiz
so instanciam modulos de `modules/` e ligam a saida de um na entrada do outro. A
divisao em arquivos e organizacional (o Terraform le tudo como um arquivo so):

| Arquivo | Conteudo |
| --- | --- |
| `network.tf` | `module.vpc` |
| `ecr.tf` | `module.ecr` |
| `iam.tf` | `module.github_oidc`, `module.iam_app`, `module.iam_terraform` |
| `app.tf` | ALB, security groups e o servico ECS da aplicacao |
| `sandbox.tf` | servico descartavel ([ADR-0013](0013-servico-sandbox-descartavel.md)) |
| `moved.tf` | renomeacoes pendentes de apply |

Cada modulo em `modules/<nome>/` tem `main.tf`, `variables.tf`, `outputs.tf`,
`versions.tf` e `README.md` gerado. Recursos dentro dos modulos chamam-se `this`;
blocos de modulo na raiz usam underscore (`ecs_app`, `sg_alb`). Todo recurso e
nomeado a partir de `var.name`.

Os modulos sao **escritos aqui**, nao consumidos de registries publicos.

## Alternativas consideradas

- **`terraform-aws-modules/*` do registry** — maduros e testados, mas trazem uma
  superficie de inputs muito maior que a usada, escondem o que esta sendo criado
  atras de camadas de `for_each`, e amarram upgrades ao calendario do upstream.
  Como este projeto tambem serve de estudo da infra, escrever os modulos e parte
  do objetivo.
- **Recursos direto na raiz, sem modulos** — mais curto para poucos recursos, mas
  impede reuso (dois servicos ECS no mesmo cluster, varios security groups) e
  torna o `plan` da raiz ilegivel.
- **Um repositorio por modulo, versionado por tag** — versionamento independente
  de verdade, ao custo de N repositorios e um bump de versao a cada ajuste, para
  um consumidor so.

## Consequencias

- Ler a raiz mostra a topologia inteira do sistema em poucas dezenas de linhas.
- Trocar a implementacao de uma peca e trocar o conteudo de um modulo, sem tocar
  na composicao.
- Como os modulos sao locais e sem versao, **uma mudanca em `modules/` afeta todos
  os ambientes no proximo apply** — nao ha pin por consumidor. Mudanca que quebra
  compatibilidade precisa de `moved` ou de rollout coordenado.
- Renomear um bloco de modulo troca o endereco no state e destruiria/recriaria os
  recursos; por isso `moved.tf` existe na raiz. E **temporario**: apagar depois que
  o apply rodar em todos os ambientes que ja tinham state (hoje, so prod).
- Novos modulos herdam a mesma estrutura de arquivos; a skill `modularizar-aws`
  existe para nao reescrever esse esqueleto a mao.
