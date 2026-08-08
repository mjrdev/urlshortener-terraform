# ADR 0009 — Security groups com regras declaradas como mapa

- **Status:** aceito
- **Data:** 2026-08-08

## Contexto

Regras de security group escritas como blocos `ingress`/`egress` embutidos em
`aws_security_group` sofrem de dois problemas: a AWS reordena as regras, gerando
diff fantasma, e a lista inteira e um unico atributo — mudar uma regra reescreve
todas. Com listas passadas por variavel o problema piora: o indice numerico e a
identidade no state, entao remover a primeira regra de uma lista de tres desloca
as outras duas e o Terraform recria o que nao mudou.

## Decisao

`modules/security-group` recebe `ingress_rules` e `egress_rules` como
`map(object(...))`, e cada entrada vira um `aws_vpc_security_group_ingress_rule` /
`aws_vpc_security_group_egress_rule` separado, via `for_each`. **A chave do mapa e
a identidade da regra no state.**

Cada regra aceita exatamente uma origem — `cidr_ipv4`, `cidr_ipv6`,
`prefix_list_id` ou `referenced_security_group_id` — garantido por `validation`,
porque a API aceitaria o recurso e produziria uma regra diferente da pretendida.
Uma segunda validacao exige `from_port` quando `ip_protocol` nao e `-1`.

Referencia entre security groups usa `referenced_security_group_id`, nao CIDR: em
`app.tf`, `sg_ecs_tasks` libera a porta da aplicacao apenas para `sg_alb.id`.

## Alternativas consideradas

- **Blocos `ingress`/`egress` inline** — o diff instavel e a reescrita do conjunto
  inteiro a cada mudanca; e o modelo que a AWS depreciou em favor dos recursos de
  regra individuais.
- **Lista em vez de mapa** — mesma granularidade de recurso, mas com indice como
  identidade: qualquer insercao no meio embaralha o state.
- **Um modulo por security group concreto** — perde o reuso; hoje o mesmo modulo
  atende ALB, tasks da aplicacao e sandbox.

## Consequencias

- Adicionar ou remover uma regra afeta so aquela regra no plan.
- **Renomear a chave do mapa recria a regra** (destroi e cria). Para HTTP publico
  isso e irrelevante; para uma regra que e a unica entrada de um servico em uso, ha
  uma janela sem a regra. Renomeacao intencional pede um `moved`.
- Erro de composicao (duas origens, ou porta faltando) falha no `plan`, com
  mensagem propria, em vez de virar uma regra silenciosamente errada na AWS.
- **Sem `egress_rules` o security group nao tem saida nenhuma**:
  `aws_security_group` sozinho nao cria a regra `allow all` default que o console
  sugere. Todo SG que precisa falar com o mundo declara explicitamente
  `{ all = { cidr_ipv4 = "0.0.0.0/0", ip_protocol = "-1" } }`.
