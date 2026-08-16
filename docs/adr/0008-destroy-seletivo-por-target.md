# ADR 0008 — Destroy seletivo por `-target`, preservando o acesso da pipeline

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

Este e um ambiente de estudo: derrubar tudo para nao pagar NAT, ALB e Fargate
enquanto nao esta em uso e um requisito, nao um acidente. Mas um
`terraform destroy` completo levaria junto `module.github_oidc` e
`module.iam_terraform` — que sao exatamente como a pipeline se autentica na conta
([ADR-0006](0006-autenticacao-da-ci-via-github-oidc.md)). Sem eles, nao ha como
rodar o apply que recriaria tudo: a pipeline se destroi e nao consegue voltar.

Alem disso os dois estao protegidos por `prevent_destroy`
([ADR-0007](0007-prevent-destroy-como-input-de-modulo.md)), e `prevent_destroy`
aborta o **plan inteiro** — um destroy sem `-target` nem chegaria a destruir os
outros recursos.

## Decisao

O workflow `.github/workflows/terraform-destroy.yaml` e `workflow_dispatch` manual,
com um input em que a palavra `destroy` precisa ser digitada (`if:` no job), e
destroi por `-target` explicito, listando os modulos na ordem inversa da
dependencia:

```
-target=module.ecs_app    -target=module.sg_ecs_tasks
-target=module.alb        -target=module.sg_alb
-target=module.vpc        -target=module.ecr
-target=module.iam_app
```

`module.github_oidc` e `module.iam_terraform` **nao aparecem na lista** — a
omissao e a decisao. O destroy roda em dois passos, `plan -destroy -out` e depois
`apply` do plano salvo, como no workflow normal.

## Alternativas consideradas

- **`terraform destroy` sem `-target`** — impossivel: o `prevent_destroy` faz o
  plan falhar, e se nao fizesse, apagaria o acesso da pipeline.
- **Separar os recursos de bootstrap num root/state proprio** — a solucao limpa: o
  destroy daqui nunca alcancaria o que nao esta neste state, e a lista de
  `-target` sumiria. Custa um segundo state e cruzar outputs entre roots. E o
  caminho natural se a lista continuar crescendo.
- **Destroy so local, sem workflow** — sem OIDC no terminal, seria preciso
  credencial de longa duracao na maquina, contra o ADR-0006.

## Consequencias

- **A lista e manual e precisa ser mantida.** Ao acrescentar um modulo que deve ser
  destruivel, acrescente o `-target` correspondente ao workflow — senao o recurso
  sobrevive ao destroy, silenciosamente, e continua sendo cobrado.
- `-target` desliga a resolucao normal de dependencias: a ordem dos alvos importa e
  um alvo faltando pode fazer o destroy falhar no meio, deixando a infra parcial.
- O Terraform emite o aviso de que `-target` e recurso de excecao. Aqui e uso
  deliberado e permanente, nao workaround pontual.
- Depois do destroy, o state fica com o provider OIDC e as duas roles protegidas.
  Um `apply` normal reconstroi o resto.
- O gatilho manual com confirmacao digitada e a unica barreira contra um destroy
  acidental — nao ha environment com approval configurado.
