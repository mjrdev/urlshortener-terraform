# modules/vpc

VPC com subnets publicas e privadas distribuidas em N zonas de disponibilidade,
internet gateway e NAT gateway.

Os CIDRs das subnets sao derivados do `vpc_cidr` com `cidrsubnet(..., 8, i)` — as
`subnet_count` primeiras faixas /24 vao para as publicas e as seguintes para as
privadas. Aumentar `subnet_count` acrescenta subnets no fim da lista sem mexer nas
existentes; diminuir destroi as ultimas.

`single_nat_gateway = true` deixa um NAT so, compartilhado por todas as subnets
privadas: mais barato e ponto unico de falha. Com `false`, sai um NAT por AZ, cada
subnet privada roteando pelo NAT da propria zona.

```hcl
module "vpc" {
  source = "./modules/vpc"

  name               = "urlshortener"
  vpc_cidr           = "10.0.0.0/16"
  subnet_count       = 3
  single_nat_gateway = true
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | n/a | `string` | n/a | yes |
| single\_nat\_gateway | true cria um unico NAT Gateway compartilhado; false cria um por AZ (alta disponibilidade, custo maior). | `bool` | `true` | no |
| subnet\_count | Quantidade de subnets por tier. O mesmo valor cria N subnets publicas e N privadas. | `number` | `3` | no |
| vpc\_cidr | n/a | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| availability\_zones | n/a |
| nat\_gateway\_ids | n/a |
| private\_subnet\_ids | n/a |
| public\_subnet\_ids | n/a |
| vpc\_cidr | n/a |
| vpc\_id | n/a |
<!-- END_TF_DOCS -->
