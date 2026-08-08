# ADR 0001 — Registrar decisoes de arquitetura em ADRs

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

Boa parte das escolhas desta infraestrutura nao e obvia lendo o HCL: o backend e
parcial, `prevent_destroy` alterna entre dois recursos gemeos, o workflow de
destroy usa `-target` a dedo, o Terraform de proposito nao faz deploy da
aplicacao. Hoje esse conhecimento esta espalhado em comentarios, no `README.md` e
no `CLAUDE.md` — que explicam **o que** o codigo faz, mas raramente **por que** a
alternativa mais simples foi descartada. Sem isso, cada revisao do codigo recomeca
a mesma discussao, e o risco maior e alguem "simplificar" algo que existe por um
motivo caro de aprender (recriar a role da propria pipeline, por exemplo).

## Decisao

Registrar as decisoes com efeito duradouro em Architecture Decision Records, um
arquivo por decisao em `docs/adr/`, numerados sequencialmente
(`NNNN-slug.md`) a partir do `template.md`. Um ADR nunca e editado para mudar de
rumo: quando a decisao muda, cria-se um novo ADR e o antigo passa a
`substituido por [ADR-NNNN]`. Correcao de texto e link, sim, pode ser editada.

Os ADRs cobrem decisoes: escolha de servico, topologia de rede, fronteira entre
Terraform e pipeline, estrategia de state. Nao cobrem referencia de uso — os
inputs e outputs de cada modulo continuam nos `README.md` gerados pelo
terraform-docs ([ADR-0012](0012-readme-gerado-por-terraform-docs.md)), e o guia
de comandos do dia a dia continua no `README.md` da raiz.

## Alternativas consideradas

- **So comentarios no HCL** — bons para o "porque" local de uma linha, mas nao
  cabem numa decisao que atravessa varios arquivos, e somem quando o recurso
  comentado e reescrito.
- **Uma secao "decisoes" no README** — cresce sem ordem, mistura decisao vigente
  com decisao revogada e nao tem como marcar uma como superada.

## Consequencias

- Toda mudanca estrutural passa a ter um lugar previsto para a justificativa; PRs
  que mudam topologia devem acrescentar ou atualizar um ADR.
- Os ADRs sao um retrato datado. Um ADR aceito descreve a intencao vigente, mas o
  codigo continua sendo a fonte da verdade sobre o estado atual.
- O `README.md` e o `CLAUDE.md` seguem existindo com outro papel: como operar e
  como o codigo esta organizado, respectivamente.
