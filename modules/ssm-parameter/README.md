# modules/ssm-parameter

Parametro no SSM Parameter Store. Existe para guardar segredo de aplicacao — senha de
banco, chave de assinatura — sem que ele apareca na task definition nem em arquivo
versionado: o consumidor recebe o ARN e o ECS resolve o valor na partida da task.

O tier Standard e gratuito e cobre valores de ate 4 KB. Com `type = "SecureString"` e
`key_id` nulo, a criptografia usa a chave gerenciada `alias/aws/ssm` — com ela a role de
execucao das tasks precisa apenas de `ssm:GetParameters`, que `modules/ecs` ja concede
sozinho a partir do input `secrets`.

**O valor vai para o state.** Em troca nao ha custo por segredo nem rotacao para manter;
se o ambiente deixar de ser descartavel, Secrets Manager passa a ser a escolha certa.

```hcl
module "ssm_db_password" {
  source = "./modules/ssm-parameter"

  name        = "/urlshortener/db-password"
  description = "Senha do usuario master do Postgres"
  value       = random_password.db.result
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.0.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Nome (caminho) do parametro, ex: /urlshortener/db-password. | `string` | n/a | yes |
| value | Valor do parametro. Vai para o state — use um backend privado. | `string` | n/a | yes |
| description | Descricao do parametro. | `string` | `null` | no |
| key\_id | Chave KMS usada quando type e SecureString. Nulo usa a chave gerenciada<br/>`alias/aws/ssm`, que dispensa `kms:Decrypt` na role de execucao das tasks. | `string` | `null` | no |
| tags | Tags adicionais aplicadas ao parametro. | `map(string)` | `{}` | no |
| tier | Standard e gratuito e cobre valores de ate 4 KB. | `string` | `"Standard"` | no |
| type | String, StringList ou SecureString. | `string` | `"SecureString"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN do parametro — use no `secrets` da task definition. |
| name | Nome (caminho) do parametro. |
<!-- END_TF_DOCS -->
