---
name: provisionar-recurso
description: Provisiona um recurso AWS no root module instanciando um modulo de modules/ com as variaveis que o usuario pediu — escolhe o arquivo .tf certo da raiz (ecr.tf, network.tf, app.tf... ou cria um novo), cria as variaveis de ambiente em variables.tf e environments/*.tfvars, liga dependencias (security group, IAM, subnets) e acrescenta o -target no workflow de destroy. Use sempre que o usuario pedir para criar/subir/adicionar/provisionar um recurso concreto na infra — "cria um bucket s3 com versionamento e bloqueio de acesso publico", "sobe uma fila sqs pra isso", "adiciona um repositorio ecr novo", "quero um alb interno" — ou pedir para mudar a configuracao de um recurso ja instanciado. Se o modulo necessario ainda nao existir em modules/, esta skill pergunta ao usuario se deve cria-lo.
---

# Provisionar um recurso no root

Aqui o root module **so instancia modulos locais** — nenhum `resource` mora na raiz.
Provisionar um recurso significa: achar (ou criar) o modulo em `modules/`, escrever o
bloco `module` no `.tf` tematico certo da raiz, e ligar as pontas soltas (variaveis por
ambiente, security group, IAM, outputs, destroy).

O pedido do usuario descreve o **resultado** ("um bucket privado com versionamento"),
nao os inputs. Seu trabalho e traduzir isso para os inputs que o modulo expoe.

## Fluxo

### 1. Ver o que ja existe

Antes de escrever qualquer coisa, olhe:

- `ls modules/` — que modulos existem.
- `modules/<candidato>/variables.tf` e `README.md` — quais inputs ele expoe e com que
  defaults. **Leia os inputs de verdade**; nao invente nomes de argumento.
- os `.tf` da raiz — como recursos parecidos ja foram instanciados e o que da para reusar
  (`module.vpc.private_subnet_ids`, `module.ecr.repository_url`, um security group ja
  existente).

### 2. Decidir se o modulo atende

Tres casos:

**Atende.** Siga para o passo 3.

**Nao existe modulo para esse servico.** Pare e pergunte ao usuario, de forma direta:
o modulo `modules/s3` ainda nao existe — quer que eu crie? Diga em uma linha o que o
modulo teria (os recursos e os inputs principais) para a resposta ser informada. **Nao
crie o modulo sem confirmacao, e nunca escreva o `resource` direto na raiz como atalho.**
Com o sim, use o skill `modularizar-aws` para criar o modulo e volte para ca.

**Existe mas nao expoe o que o usuario pediu.** Mesma coisa: diga qual input falta e
pergunte se pode estender o modulo. Estender e quase sempre melhor que contornar na
raiz — se voce se pegar recriando na raiz algo que o modulo deveria fazer, e sinal de
que o modulo e que precisa mudar.

Se o usuario disser nao, entregue o que da para entregar com o modulo atual e diga
claramente o que ficou de fora.

### 3. Escolher o arquivo da raiz

A divisao em arquivos e organizacional (o Terraform le tudo como um so), mas siga o
assunto. Se ja existe um arquivo do contexto, **escreva nele** — nao crie um arquivo novo
para um recurso que pertence a um assunto existente:

| Assunto | Arquivo |
|---|---|
| VPC, subnets, NAT, rede | `network.tf` |
| Repositorios de imagem | `ecr.tf` |
| Roles, OIDC, politicas | `iam.tf` |
| ALB, servico ECS da aplicacao e seus SGs | `app.tf` |
| Servicos descartaveis de teste | `sandbox.tf` |

Nao havendo arquivo do assunto, crie um com nome curto no plural do dominio —
`storage.tf` (S3, EFS), `data.tf` ou `database.tf` (RDS, DynamoDB), `messaging.tf`
(SQS, SNS), `dns.tf` (Route53, ACM), `cdn.tf` (CloudFront). Prefira acrescentar a um
arquivo existente a espalhar um arquivo por recurso.

Um caso comum: o recurso e do assunto de um arquivo que existe, mas o usuario pediu algo
claramente separado (um bucket de assets do site vs. um bucket de backups). Continuam no
mesmo `storage.tf`, com blocos de nome diferente — o arquivo agrupa assunto, nao instancia.

### 4. Escrever o bloco

```hcl
module "s3_assets" {
  source = "./modules/s3"

  name = "${var.name}-assets"

  versioning = true

  # Bucket servido pelo CloudFront: acesso publico so pela distribuicao.
  block_public_access = true
}
```

- Nome do bloco em underscore, com o servico como prefixo e o papel como sufixo
  (`s3_assets`, `sqs_eventos`, `rds_app`) — e assim que `sg_alb`, `ecs_app` e `iam_app`
  ja se chamam.
- `name` sempre derivado de `var.name`, para os ambientes nao colidirem.
- `source` relativo, linha em branco depois dele.
- Passe so os inputs que voce esta realmente mudando; deixe o resto no default do modulo.
- Comentario acima do argumento cujo motivo nao e obvio pelo nome. O que o usuario disse
  ("precisa versionar porque ja perdemos arquivo") vale mais como comentario do que
  qualquer descricao generica.
- Portugues sem acentos, como o resto do repo.

### 5. Variaveis: literal ou por ambiente?

A regra e o que muda entre dev e prod:

- **Muda por ambiente** (sizing, retencao, contagem, portas, flags de custo) → crie
  `variable` em `variables.tf` da raiz, na secao do assunto, com `description` e default;
  e defina o valor em **todos** os `environments/*.tfvars`, inclusive
  `example.tfvars`, com um comentario curto. Ambiente esquecido vira surpresa no plan.
- **Nao muda** (uma flag que e verdade para o stack todo, um papel fixo) → literal no
  bloco. Nao crie variavel para valor que so tem uma resposta correta.
- **Segredo** → `sensitive = true` e fora do tfvars versionado; documente que vem por
  `TF_VAR_*` / secret do CI, como `app_repository` ja faz.

### 6. Ligar as dependencias

Verifique cada uma antes de terminar:

- **Rede** — recurso com ENI (RDS, EFS, Lambda em VPC, ECS) vai nas subnets privadas
  (`module.vpc.private_subnet_ids`); so o que precisa ser alcancado da internet vai nas
  publicas.
- **Security group** — se o recurso tem SG, crie um bloco `modules/security-group`
  (`sg_<recurso>`) no mesmo arquivo, acima do recurso, liberando o minimo: prefira
  `referenced_security_group_id` do consumidor a CIDR aberto.
- **IAM da aplicacao** — se a aplicacao precisa acessar o recurso em runtime, acrescente
  uma policy em `module.iam_app` em `iam.tf`, com `resources` escopado no ARN do recurso
  (como `ecr-push` faz). Nao crie IAM solto.
- **IAM da pipeline (obrigatorio, servico novo sempre precisa)** — `module.iam_terraform`
  **nao tem `AdministratorAccess`**: o input `policies` lista so as acoes que os modulos
  chamam de fato (ADR-0014). Servico novo sem entrada la faz o `apply` parar com
  `AccessDenied` **no meio**, com parte da infra criada. Acrescente em `iam.tf` uma
  policy nova com as acoes de ciclo de vida do servico (create/delete/describe/tag do
  recurso, na conta so o que o Terraform chama), escopada no ARN quando o servico
  suportar resource-level — e no conjunto de acoes quando nao suportar. Nao resolva isso
  reanexando `AdministratorAccess`.
  Dois limites: a AWS permite **10 politicas gerenciadas por role e o teto ja esta
  atingido**, entao agrupe a acao nova numa policy existente do mesmo dominio em vez de
  criar a 11a; e o id da conta vem de `local.account_id` (`data.aws_caller_identity`),
  nunca literal — o repositorio e publico.
- **Outputs** — exporte em `outputs.tf` da raiz, na secao certa, so o que alguem de fora
  usa (endpoint, ARN, URL, nome do bucket).
- **Destroy** — acrescente `-target=module.<nome>` em
  `.github/workflows/terraform-destroy.yaml`, antes dos targets de que ele depende (o
  dependente vem primeiro). Nao inclua nada de que a pipeline dependa para se autenticar
  (`module.github_oidc`, `module.iam_terraform` ficam de fora de proposito).

### 7. Fechar

```bash
terraform fmt -recursive
terraform validate    # exige init com -backend-config=environments/<env>.backend.hcl
terraform-docs markdown table --recursive --recursive-path modules --config .terraform-docs.yml .
```

O `terraform-docs` e necessario sempre que voce mexeu em variaveis ou outputs (da raiz ou
de um modulo). Se `validate` precisar de backend/credencial que voce nao tem, diga isso
em vez de afirmar que validou. Rode `plan` so se o usuario pedir; nunca `apply`.

## Encerramento

Termine com um resumo curto:

- o bloco criado e em que arquivo;
- as variaveis novas e o valor que ficou em cada ambiente;
- o que voce ligou (SG, IAM, output, destroy target);
- o que o usuario ainda precisa decidir ou rodar (`plan`/`apply`, valor de tfvars, um
  nome globalmente unico como o de bucket S3).

E util avisar quando a mudanca **recria** algo em vez de alterar: bucket renomeado,
chave de mapa de regra renomeada, flag `prevent_destroy` alternada. Isso aparece no plan
como destroy/create e vale ser dito antes.
