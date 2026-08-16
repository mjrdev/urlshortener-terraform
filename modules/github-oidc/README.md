# modules/github-oidc

Provider OIDC do GitHub Actions na conta AWS.

O provider e **unico por conta**: um so recurso atende todas as roles de todos os
repositorios, por isso mora num modulo separado instanciado uma vez so. Nao precisa
de `thumbprint_list` — a AWS valida o certificado do GitHub pelas CAs raiz dela.

`prevent_destroy = true` e o padrao recomendado: destruir o provider invalidaria de
uma vez a trust policy de todas as roles do GitHub Actions. Com a trava ligada,
qualquer plano que remova o recurso falha ainda no plan. Para remover de verdade,
mude para `false`, aplique, e so entao apague o modulo.

```hcl
module "github_oidc" {
  source = "./modules/github-oidc"

  prevent_destroy = true
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
| [aws_iam_openid_connect_provider.protected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| oidc\_host | Host do emissor OIDC do GitHub. Só muda em GitHub Enterprise Server. | `string` | `"token.actions.githubusercontent.com"` | no |
| prevent\_destroy | Trava o provider OIDC contra destroy. Com true, qualquer plano que o remova<br/>— inclusive `terraform destroy` do stack inteiro — falha ainda no plan.<br/>Destruir o provider invalidaria a trust policy de todas as roles do GitHub<br/>Actions de uma vez, entao a trava e a protecao mais ampla do stack.<br/><br/>Para deletar de verdade depois, mude para false, aplique, e so entao remova<br/>o modulo. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN do provider OIDC — passar para cada modulo de role. |
| host | Host sem esquema — usado ao montar as condicoes `aud` e `sub`. |
| url | URL do provider, com esquema. |
<!-- END_TF_DOCS -->
