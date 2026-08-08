# Convencoes dos modulos deste repositorio

Padroes extraidos de `modules/vpc`, `ecr`, `ecs`, `elb`, `security-group`, `iam` e
`github-oidc`. Siga-os para que o modulo novo nao destoe.

## Indice

- [Estrutura de arquivos](#estrutura-de-arquivos)
- [Nomes](#nomes)
- [Tags](#tags)
- [variables.tf](#variablestf)
- [Colecoes: map(object) em vez de listas](#colecoes-mapobject-em-vez-de-listas)
- [Recurso opcional: count](#recurso-opcional-count)
- [prevent_destroy como input](#prevent_destroy-como-input)
- [outputs.tf](#outputstf)
- [Comentarios](#comentarios)
- [Blocos moved e lifecycle](#blocos-moved-e-lifecycle)
- [Instanciacao no root](#instanciacao-no-root)

## Estrutura de arquivos

Sempre os mesmos cinco arquivos, mesmo que algum fique curto:

```
modules/<nome>/
├── main.tf        # os resources, agrupados por secao com cabecalho de comentario
├── variables.tf   # inputs, agrupados na mesma ordem logica do main.tf
├── outputs.tf     # so o que o consumidor precisa
├── versions.tf    # identico em todos os modulos (assets/versions.tf)
└── README.md      # texto a mao + tabelas do terraform-docs
```

Pasta em kebab-case quando o nome tem duas palavras (`security-group`, `github-oidc`).

Secoes dentro do `main.tf` sao separadas assim:

```hcl
##########################
# Cluster
##########################
```

## Nomes

- Recurso principal do modulo: `resource "aws_xxx" "this"`.
- Recursos secundarios com `for_each`: tambem `this` (o `for_each` ja distingue).
- Nome AWS sempre derivado de `var.name`, com sufixo quando ha mais de um recurso do
  mesmo tipo: `"${var.name}-${each.key}"`, `"${var.name}-tg"`.
- Atencao a limites de tamanho da AWS (target group: 32 chars; bucket S3: 63 chars e
  globalmente unico). Quando existir limite apertado, documente no README e, se fizer
  sentido, valide em `variable`.

## Tags

```hcl
tags = merge({ Name = var.name }, var.tags)
```

Sempre. As tags comuns do stack (`Owner`, `By`) vem de `default_tags` no provider da
raiz — nao as repita. `var.tags` e `map(string)` com default `{}`.

## variables.tf

- Toda variavel tem `description`, exceto `name` (que dispensa por obviedade em alguns
  modulos, mas escrever nao machuca).
- Ordem: obrigatorias primeiro, depois opcionais; agrupadas por assunto com o mesmo
  cabecalho `####` do main.tf quando o arquivo cresce.
- Defaults refletem o que este stack quer (seguro e barato), nao o default da AWS.
- `description` longa usa heredoc:

```hcl
variable "single_nat_gateway" {
  description = <<-EOT
    Com true, um unico NAT gateway atende todas as subnets privadas: mais barato e
    ponto unico de falha. Com false, sai um NAT por AZ.
  EOT
  type        = bool
  default     = true
}
```

- `validation` para invariantes que a AWS so reclamaria no apply, com `error_message`
  que diz o que fazer.
- `sensitive = true` no que for segredo — essas variaveis nao vao para tfvars versionado.

## Colecoes: map(object) em vez de listas

Quando o modulo aceita N coisas do mesmo tipo (regras, politicas, statements,
lifecycle rules, notificacoes), receba `map(object({...}))` com `optional(...)` e use
`for_each`. A chave do mapa e o nome logico **e a identidade no state** — renomear a
chave recria o recurso. Diga isso na `description`.

```hcl
variable "lifecycle_rules" {
  description = <<-EOT
    Regras de ciclo de vida, indexadas por nome logico. A chave do mapa e a identidade
    da regra no state — renomear a chave recria a regra.

    Exemplo:
      { expira-logs = { prefix = "logs/", expiration_days = 30 } }
  EOT
  type = map(object({
    prefix          = optional(string)
    expiration_days = optional(number)
  }))
  default = {}
}
```

Sempre inclua um `Exemplo:` no heredoc — e o que faz a tabela do terraform-docs ficar
legivel.

Nunca `list(object)` para isso: a ordem da lista vira indice no state e inserir no meio
recria tudo.

## Recurso opcional: count

Quando um recurso so deve existir se o consumidor nao trouxe o dele de fora, use
`count` no recurso e `coalesce` no local:

```hcl
resource "aws_ecs_cluster" "this" {
  count = var.cluster_arn == null ? 1 : 0
  ...
}

locals {
  cluster_arn = coalesce(var.cluster_arn, one(aws_ecs_cluster.this[*].arn))
}
```

Os outputs saem do `local`, nunca do recurso direto — assim funcionam nos dois modos.

## prevent_destroy como input

`prevent_destroy` nao aceita expressao, entao quando a protecao precisa ser
configuravel o modulo tem **dois recursos gemeos** e um `local` que escolhe:

```hcl
resource "aws_iam_role" "this" {
  count = var.prevent_destroy ? 0 : 1
  # ... argumentos identicos ...
}

resource "aws_iam_role" "protected" {
  count = var.prevent_destroy ? 1 : 0
  # ... argumentos identicos ...

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  role_arn = one(concat(aws_iam_role.this[*].arn, aws_iam_role.protected[*].arn))
}
```

Custo: alternar a flag **recria o recurso**. Use so onde a protecao vale isso (hoje:
`iam` e `github-oidc`) e avise no README.

## outputs.tf

- Toda saida com `description` que diz **para que serve**, nao so o que e:
  `"URL do repositorio — destino do docker push."`
- Exporte o que outro modulo ou o root vai consumir (id, arn, name, endpoint) — nao o
  objeto inteiro.
- Colecoes viram mapa pela mesma chave logica do input:
  `{ for k, v in aws_iam_policy.this : k => v.arn }`.
- Nomes curtos e sem repetir o modulo: `id`, `arn`, `name` (o consumidor ja escreve
  `module.sg_alb.id`). Use prefixo so quando ha mais de um recurso do mesmo tipo
  (`repository_url`, `target_group_arn`).

## Comentarios

Explique decisao e pegadinha, nunca o obvio:

```hcl
# IMMUTABLE impede sobrescrever uma tag ja publicada; nao existe "READ_ONLY".
image_tag_mutability = var.immutable_tags ? "IMMUTABLE" : "MUTABLE"
```

Bons gatilhos para comentar: limite ou comportamento estranho da AWS, motivo de um
`lifecycle`, motivo de um `count`, escolha de custo, e o que acontece com o state se
alguem mudar aquilo.

## Blocos moved e lifecycle

- Mudou o endereco de um recurso ja aplicado (ganhou `count`, mudou de nome, virou
  submodulo)? Escreva o `moved` junto, com comentario dizendo o que seria destruido sem
  ele. `moved` na raiz vai para `moved.tf` e e temporario.
- `create_before_destroy` quando o recurso nao pode sumir enquanto outro o referencia
  (target group x listener).
- `ignore_changes` quando outro processo e o dono do valor (ex.: `task_definition` e
  `desired_count` no ECS, que vem da pipeline do app e do autoscaling) — sempre com
  comentario explicando quem e o dono.

## Instanciacao no root

```hcl
module "sg_alb" {
  source = "./modules/security-group"

  name        = "${var.name}-alb-ecs"
  description = "ALB cluster ecs"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https = {
      description = "HTTPS publico"
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 443
      ip_protocol = "tcp"
    }
  }
}
```

- Nome do bloco em underscore, agrupando por assunto (`sg_alb`, `ecs_app`, `iam_app`).
- `source` relativo, sempre `./modules/<nome>`; sem `version`.
- Uma linha em branco depois do `source`.
- Valores que mudam por ambiente vem de `var.*` da raiz, nunca hardcoded no bloco.
- Comentario acima do argumento quando a ligacao entre modulos e nao obvia
  (ex.: por que `target_type = "ip"`).
