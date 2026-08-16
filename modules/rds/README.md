# modules/rds

Instancia RDS unica com o subnet group dela. Pensado para o menor custo que ainda entrega
um banco gerenciado: `db.t4g.micro`, 20 GB gp3, Single-AZ, backup de um dia e Performance
Insights desligado. Alta disponibilidade, replica e retencao longa existem como input,
mas nenhuma delas e o padrao — quem quiser paga conscientemente.

O modulo nao cria parameter group proprio: o default da familia do Postgres ja exige TLS
(`rds.force_ssl`), que e o comportamento desejado. A aplicacao conecta com
`sslmode=require`.

**A senha e input, nao saida.** Gere com `random_password` e guarde num parametro do SSM
(`modules/ssm-parameter`); nenhum output daqui devolve o segredo.

`subnets` precisa cobrir pelo menos duas AZs — exigencia da AWS para o subnet group,
mesmo com `multi_az = false`.

```hcl
module "rds" {
  source = "./modules/rds"

  name    = "urlshortener-db"
  db_name = "urlshortener"

  subnets            = module.vpc.private_subnet_ids
  security_group_ids = [module.sg_rds.id]

  password = random_password.db.result
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
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| db\_name | Nome do banco criado na instancia. | `string` | n/a | yes |
| name | Nome do identificador da instancia e do subnet group. | `string` | n/a | yes |
| password | Senha do usuario master. Vai para o state — gere com random\_password. | `string` | n/a | yes |
| security\_group\_ids | Security groups da instancia. | `list(string)` | n/a | yes |
| subnets | Subnets do subnet group — use as privadas. | `list(string)` | n/a | yes |
| allocated\_storage | Storage inicial em GB (minimo 20 no gp3). | `number` | `20` | no |
| apply\_immediately | Aplica a mudanca na hora em vez de esperar a janela de manutencao. | `bool` | `true` | no |
| auto\_minor\_version\_upgrade | Aplica patches de versao menor na janela de manutencao. | `bool` | `true` | no |
| backup\_retention\_period | Dias de retencao do backup automatico. Zero desliga o backup. | `number` | `1` | no |
| backup\_window | Janela do backup automatico, formato hh24:mi-hh24:mi em UTC. | `string` | `null` | no |
| deletion\_protection | Trava a instancia contra destroy — exige um apply para desligar. | `bool` | `false` | no |
| engine | Engine do RDS. | `string` | `"postgres"` | no |
| engine\_version | Versao da engine. So o major deixa o patch com a AWS. | `string` | `"17"` | no |
| instance\_class | Classe da instancia. O default e a burstable mais barata. | `string` | `"db.t4g.micro"` | no |
| maintenance\_window | Janela de manutencao, formato ddd:hh24:mi-ddd:hh24:mi em UTC. | `string` | `null` | no |
| max\_allocated\_storage | Teto do autoscaling de storage em GB. Nulo desliga o autoscaling — o storage<br/>fica fixo em `allocated_storage` e o custo fica previsivel. | `number` | `null` | no |
| multi\_az | Standby em outra AZ. Dobra o custo da instancia. | `bool` | `false` | no |
| performance\_insights\_enabled | Performance Insights. Desligado por ser pago fora do periodo gratuito. | `bool` | `false` | no |
| port | Porta do banco. | `number` | `5432` | no |
| skip\_final\_snapshot | Dispensa o snapshot final no destroy. | `bool` | `true` | no |
| storage\_encrypted | Criptografia em repouso. Nao custa nada com a chave gerenciada. | `bool` | `true` | no |
| storage\_type | Tipo do volume. | `string` | `"gp3"` | no |
| tags | Tags adicionais aplicadas a instancia e ao subnet group. | `map(string)` | `{}` | no |
| username | Usuario master. | `string` | `"postgres"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| address | Host da instancia, sem porta. |
| arn | ARN da instancia — use ao escopar politicas IAM. |
| db\_name | Nome do banco criado na instancia. |
| endpoint | Endpoint no formato host:porta. |
| identifier | Identificador da instancia. |
| port | Porta do banco. |
<!-- END_TF_DOCS -->
