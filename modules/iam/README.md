# modules/iam

Role IAM com trust policy montada por dados, policies inline geradas a partir de um
mapa e anexo de policies gerenciadas.

A trust policy vem em `trust_statements`, no formato do
`aws_iam_policy_document` — o modulo nao assume federacao nem servico algum, entao
serve tanto para OIDC do GitHub quanto para roles de servico.

`prevent_destroy` alterna entre dois recursos `aws_iam_role` equivalentes (um com a
trava de lifecycle, outro sem), porque `lifecycle` nao aceita expressao. Ligar ou
desligar a flag **move a role entre os dois enderecos do state** e recria o recurso;
em role com policies anexadas, prefira ligar a trava desde a criacao.

```hcl
module "iam_app" {
  source = "./modules/iam"

  name        = "urlshortener-github-actions"
  description = "Role assumida pelo GitHub Actions"

  trust_statements = local.github_actions_trust["app"]

  policies = {
    ecr-auth = {
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }
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
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.protected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Nome da role. Tambem prefixa o nome das politicas criadas. | `string` | n/a | yes |
| trust\_statements | Statements da trust policy (quem pode assumir a role). Generico: serve para<br/>service principals, cross-account, OIDC ou SAML.<br/><br/>Exemplo de service principal:<br/>  [{ principals = [{ type = "Service", identifiers = ["ec2.amazonaws.com"] }] }]<br/><br/>Exemplo federado com condicoes:<br/>  [{<br/>    actions    = ["sts:AssumeRoleWithWebIdentity"]<br/>    principals = [{ type = "Federated", identifiers = [provider\_arn] }]<br/>    conditions = [{ test = "StringLike", variable = "...:sub", values = ["..."] }]<br/>  }] | <pre>list(object({<br/>    effect  = optional(string, "Allow")<br/>    actions = optional(list(string), ["sts:AssumeRole"])<br/>    principals = list(object({<br/>      type        = string<br/>      identifiers = list(string)<br/>    }))<br/>    conditions = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = list(string)<br/>    })), [])<br/>  }))</pre> | n/a | yes |
| description | Descricao da role. | `string` | `null` | no |
| managed\_policy\_arns | ARNs de politicas gerenciadas pela AWS a anexar na role. | `list(string)` | `[]` | no |
| max\_session\_duration | Duracao maxima da sessao, em segundos (3600 a 43200). | `number` | `3600` | no |
| path | Path IAM da role. | `string` | `"/"` | no |
| policies | Politicas gerenciadas pelo modulo, indexadas por nome logico.<br/>A chave do mapa compoe o nome final da politica e a identidade dela no state. | <pre>map(object({<br/>    actions   = list(string)<br/>    resources = optional(list(string), ["*"])<br/>    effect    = optional(string, "Allow")<br/>  }))</pre> | `{}` | no |
| prevent\_destroy | Trava a role contra destroy. Com true, qualquer plano que remova a role —<br/>inclusive `terraform destroy` do stack inteiro — falha ainda no plan.<br/><br/>Para realmente deletar depois, mude para false, aplique, e so entao remova<br/>o modulo. Alternar o valor recria a role: a que sai e a que entra sao<br/>recursos diferentes no state, entao o destroy da antiga tambem esbarra na<br/>trava. Trocar exige `terraform state mv` entre aws\_iam\_role.protected[0] e<br/>aws\_iam\_role.this[0]. | `bool` | `false` | no |
| tags | Tags adicionais aplicadas na role e nas politicas. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| assume\_role\_policy | JSON da trust policy gerada — util para inspecionar ou testar. |
| policy\_arns | ARNs das politicas criadas, por nome logico. |
| role\_arn | ARN da role. |
| role\_name | Nome da role. |
| role\_unique\_id | ID unico da role, atribuido pela AWS. |
<!-- END_TF_DOCS -->
