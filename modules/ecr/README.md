# modules/ecr

Repositorio ECR privado para as imagens da aplicacao, com scan
automatico a cada push.

`immutable_tags` decide se uma tag ja publicada pode ser sobrescrita. IMMUTABLE e o
recomendado para producao: garante que `app:v1` sempre aponte para a mesma imagem.

```hcl
module "ecr" {
  source = "./modules/ecr"

  name = "urlshortener-ecr"
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
| [aws_ecr_repository.ecr_repo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | n/a | `string` | n/a | yes |
| immutable\_tags | Se true, uma tag publicada nao pode ser sobrescrita. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| repository\_arn | ARN do repositorio — use ao escopar politicas IAM. |
| repository\_name | Nome do repositorio. |
| repository\_url | URL do repositorio — destino do docker push. |
<!-- END_TF_DOCS -->
