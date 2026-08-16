# modules/elasticache

Cache ElastiCache de no unico com o subnet group dele. `valkey` por padrao: fala o mesmo
protocolo do Redis — qualquer cliente Redis conecta sem mudanca — e custa cerca de 20%
menos por no.

O recurso e `aws_elasticache_replication_group` com **um** no, e nao
`aws_elasticache_cluster`: o recurso de cluster aceita apenas `memcached` e `redis`, entao
grupo e o unico caminho para Valkey. Com `num_cache_nodes = 1` nao ha replica nem
failover — o grupo e so a embalagem da engine.

Configuracao pensada para o menor custo: `cache.t4g.micro`, um no, sem replica, sem
Multi-AZ, sem TLS e sem auth token. O isolamento vem da rede: subnets privadas e um
security group que so aceita a origem das tasks da aplicacao. Quem conecta usa apenas
host e porta.

**O cache e descartavel.** Sem replica nao ha failover, e recriar o cluster devolve um
cache vazio — o que e aceitavel para cache e nao seria para dado duravel.

`num_cache_nodes` acima de 1 liga o failover automatico sozinho e multiplica o custo; o
output `address` devolve sempre o endpoint primario.

```hcl
module "redis" {
  source = "./modules/elasticache"

  name = "urlshortener-cache"

  subnets            = module.vpc.private_subnet_ids
  security_group_ids = [module.sg_redis.id]
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
| [aws_elasticache_replication_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Nome do cluster e do subnet group. | `string` | n/a | yes |
| security\_group\_ids | Security groups do cluster. | `list(string)` | n/a | yes |
| subnets | Subnets do subnet group — use as privadas. | `list(string)` | n/a | yes |
| apply\_immediately | Aplica a mudanca na hora em vez de esperar a janela de manutencao. | `bool` | `true` | no |
| description | Descricao do replication group. Nulo gera uma a partir de `name`. | `string` | `null` | no |
| engine | valkey ou redis. Valkey fala o mesmo protocolo e custa igual ou menos. | `string` | `"valkey"` | no |
| engine\_version | Versao da engine. | `string` | `"8.0"` | no |
| maintenance\_window | Janela de manutencao, formato ddd:hh24:mi-ddd:hh24:mi em UTC. | `string` | `null` | no |
| multi\_az | Distribui os nos entre AZs. So vale com mais de um no. | `bool` | `false` | no |
| node\_type | Tipo do no. O default e o menor disponivel. | `string` | `"cache.t4g.micro"` | no |
| num\_cache\_nodes | Quantidade de nos do grupo. Com 1 nao ha replica nem failover — o mais barato.<br/>Acima de 1 o failover automatico e ligado sozinho. | `number` | `1` | no |
| parameter\_group\_name | Parameter group. Nulo usa o default da familia da engine. | `string` | `null` | no |
| port | Porta do cache. | `number` | `6379` | no |
| tags | Tags adicionais aplicadas ao cluster e ao subnet group. | `map(string)` | `{}` | no |
| transit\_encryption\_enabled | TLS na conexao. Ligado exige cliente com TLS (REDIS\_TLS=true no app). | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| address | Host do endpoint primario, sem porta. |
| arn | ARN do replication group — use ao escopar politicas IAM. |
| port | Porta do cache. |
| replication\_group\_id | Identificador do replication group. |
<!-- END_TF_DOCS -->
