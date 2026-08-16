# modules/security-group

Security group com as regras declaradas em mapas, uma regra
por entrada.

Usa `aws_vpc_security_group_ingress_rule` / `egress_rule` (recurso por regra) em vez
dos blocos `ingress`/`egress` embutidos: cada regra vira um recurso proprio no state,
entao mexer numa nao recria as outras.

A chave do mapa e a identidade da regra no state — **renomear a chave destroi e
recria** a regra correspondente. Cada regra exige exatamente uma origem/destino
(`cidr_ipv4`, `cidr_ipv6`, `prefix_list_id` ou `referenced_security_group_id`),
validado no plan.

```hcl
module "sg_alb" {
  source = "./modules/security-group"

  name        = "urlshortener-alb"
  description = "ALB publico"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https = { cidr_ipv4 = "0.0.0.0/0", from_port = 443, ip_protocol = "tcp" }
  }

  egress_rules = {
    targets = { cidr_ipv4 = module.vpc.vpc_cidr, ip_protocol = "-1" }
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
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Nome do security group. Tambem prefixa o nome das regras criadas. | `string` | n/a | yes |
| vpc\_id | Id VPC | `string` | n/a | yes |
| description | Descricao do security group. | `string` | `null` | no |
| egress\_rules | Regras de saida, indexadas por nome logico. Mesmo formato de ingress\_rules.<br/>Sem nenhuma regra o security group nao permite trafego de saida — a regra<br/>default da AWS nao e criada por aws\_security\_group sozinho.<br/><br/>Exemplo (libera tudo):<br/>  { all = { cidr\_ipv4 = "0.0.0.0/0", ip\_protocol = "-1" } } | <pre>map(object({<br/>    description                  = optional(string)<br/>    ip_protocol                  = optional(string, "tcp")<br/>    from_port                    = optional(number)<br/>    to_port                      = optional(number)<br/>    cidr_ipv4                    = optional(string)<br/>    cidr_ipv6                    = optional(string)<br/>    prefix_list_id               = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>  }))</pre> | `{}` | no |
| ingress\_rules | Regras de entrada, indexadas por nome logico. A chave do mapa nomeia a regra<br/>e e a identidade dela no state — renomear a chave recria a regra.<br/><br/>Cada regra aceita exatamente uma origem: cidr\_ipv4, cidr\_ipv6,<br/>prefix\_list\_id ou referenced\_security\_group\_id.<br/><br/>Exemplo:<br/>  {<br/>    https-ipv4 = { cidr\_ipv4 = "0.0.0.0/0", from\_port = 443, ip\_protocol = "tcp" }<br/>    app        = { referenced\_security\_group\_id = module.alb\_sg.id, from\_port = 8080, ip\_protocol = "tcp" }<br/>  } | <pre>map(object({<br/>    description                  = optional(string)<br/>    ip_protocol                  = optional(string, "tcp")<br/>    from_port                    = optional(number)<br/>    to_port                      = optional(number)<br/>    cidr_ipv4                    = optional(string)<br/>    cidr_ipv6                    = optional(string)<br/>    prefix_list_id               = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>  }))</pre> | `{}` | no |
| tags | Tags adicionais aplicadas no security group e nas regras. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN do security group. |
| egress\_rule\_ids | Ids das regras de saida, por nome logico. |
| id | Id do security group. |
| ingress\_rule\_ids | Ids das regras de entrada, por nome logico. |
| name | Nome do security group. |
<!-- END_TF_DOCS -->
