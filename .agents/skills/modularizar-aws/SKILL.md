---
name: modularizar-aws
description: Cria um modulo Terraform local para um servico AWS (S3, RDS, SQS, SNS, DynamoDB, CloudFront, Route53, EFS, Lambda, etc.) seguindo as convencoes deste repositorio, e opcionalmente liga o modulo no root. Use sempre que o usuario pedir "modularizar o s3", "modularize o rds", "cria um modulo pro sqs", "quero um modulo terraform para <servico AWS>", ou descrever um recurso AWS que precisa virar modulo em modules/ — mesmo que ele nao use a palavra "modulo" e apenas diga que quer adicionar aquele servico a infraestrutura.
---

# Modularizar um servico AWS

Este repositorio e um root module composicional: nenhum `resource` mora na raiz, so
blocos `module`. Adicionar um servico AWS aqui significa **criar `modules/<servico>/`**
no mesmo estilo dos modulos que ja existem (`vpc`, `ecr`, `ecs`, `elb`,
`security-group`, `iam`, `github-oidc`) e depois instancia-lo num `.tf` da raiz.

O objetivo nao e cuspir um modulo generico da internet: e um modulo que **parece
escrito pela mesma pessoa** que escreveu os outros, com os inputs que este stack
realmente precisa e sem knobs que ninguem vai usar.

## Fluxo

### 1. Entender o que o usuario quer

O pedido costuma vir curto ("modulariza o s3"). Antes de escrever, decida o escopo do
modulo — o que entra e o que fica de fora. Faca ate 2-3 perguntas objetivas **so quando
a resposta muda o desenho do modulo**; para o resto, escolha o default sensato e diga
qual escolheu. Perguntas que costumam valer a pena:

- **Para que serve esse recurso aqui?** (bucket de assets servido por CloudFront, bucket
  de state, fila entre servicos, banco da aplicacao...) — isso define os inputs.
- **Quem consome?** Se outra parte do stack precisa do ARN/endpoint/id, isso vira output
  e provavelmente uma policy no `modules/iam`.
- **Publico ou privado, criptografado com que chave, com que retencao?** — os defaults
  seguros ja vao no modulo; a pergunta e se algum ambiente precisa fugir deles.

Se o usuario ja despejou os requisitos no pedido, nao interrogue: confirme em uma linha
o que voce entendeu e siga.

### 2. Conferir o provider

Nao escreva argumentos de memoria. O root fixa `aws ~> 6.0`, onde varios recursos
mudaram de forma (S3 usa recursos separados para versioning/encryption/public access
block; security group usa `aws_vpc_security_group_*_rule`). Se houver duvida sobre o
nome ou formato de um argumento, consulte a documentacao do provider antes de escrever,
e confirme depois com `terraform validate`.

### 3. Escrever o modulo

Crie `modules/<nome>/` com os cinco arquivos: `main.tf`, `variables.tf`, `outputs.tf`,
`versions.tf`, `README.md`. Use `assets/versions.tf` como esta — e identico em todos os
modulos.

As convencoes de estilo (nomes, tags, `map(object)` para colecoes, `prevent_destroy`,
`count` para recurso opcional, comentarios) estao em `references/convencoes.md`. **Leia
esse arquivo antes de escrever o primeiro recurso** — e o que faz o modulo novo nao
destoar dos outros.

Regras que valem para qualquer modulo daqui:

- Tudo e nomeado a partir de `var.name`; os recursos internos se chamam `this`.
- Tags: `merge({ Name = var.name }, var.tags)`. As tags comuns vem de `default_tags` no
  provider — nao replique `Owner`/`By` no modulo.
- Comentarios, `description` de variaveis e README em **portugues sem acentos**.
- O comentario que vale a pena escrever explica **por que**, nao o que o recurso e. Se
  um argumento existe por uma limitacao da AWS, uma pegadinha de state ou uma decisao de
  custo, diga isso — foi assim que os outros modulos ficaram uteis de reler.

### 4. Escrever o README do modulo

Antes do marcador `<!-- BEGIN_TF_DOCS -->`, escreva a mao: um paragrafo do que o modulo
faz, os pontos nao obvios (limites da AWS, comportamento condicional, o que recria
recurso) e um bloco `hcl` de exemplo de uso real. Depois dos marcadores nao escreva nada
— o terraform-docs preenche. Use `assets/README-template.md` como esqueleto.

### 5. Ligar no root (so se o usuario quiser)

Modulo pronto nao e infraestrutura ligada. Pergunte se ja e para instanciar. Se sim:

1. Crie ou edite o `.tf` tematico da raiz (`storage.tf`, `data.tf`, `network.tf`...). A
   divisao de arquivos e so organizacional; agrupe pelo assunto.
2. Nome do bloco com underscore (`s3_assets`, `rds_app`), prefixado por `var.name`.
3. Inputs que variam por ambiente viram `variable` na raiz (com `description` e default)
   e entram em `environments/*.tfvars` — **inclusive `example.tfvars`**, com comentario.
4. Exporte na raiz so o que alguem de fora usa (`outputs.tf`, na secao certa).
5. Se o recurso precisa de permissao para a aplicacao ou para a pipeline, acrescente a
   policy em `module.iam_app` / `module.iam_terraform` em vez de criar IAM no modulo novo.
6. Se o modulo deve ser destruivel, acrescente o `-target=module.<nome>` em
   `.github/workflows/terraform-destroy.yaml`, na ordem de dependencia (o que depende vem
   antes). Nao inclua nada que a pipeline use para se autenticar.

### 6. Fechar

```bash
terraform fmt -recursive
terraform validate    # exige init com -backend-config=environments/<env>.backend.hcl
terraform-docs markdown table --recursive --recursive-path modules --config .terraform-docs.yml .
```

Se `validate` exigir credenciais/backend que voce nao tem, diga isso ao usuario em vez de
declarar validado. Rode o `plan` so se o usuario pedir.

No fim, resuma: arquivos criados, os inputs principais, o que ficou de fora de proposito
e o que falta o usuario decidir (valores de tfvars, wiring, destroy target).

## Recursos deste skill

- `references/convencoes.md` — os padroes de codigo extraidos dos modulos existentes,
  com exemplos. Leia antes de escrever o modulo.
- `assets/versions.tf` — copie sem alterar.
- `assets/README-template.md` — esqueleto do README do modulo.
