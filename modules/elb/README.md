# modules/elb

Application Load Balancer com target group e listeners.

O comportamento dos listeners depende de `certificate_arn`:

- **com certificado** — sobe um listener HTTPS na 443 e a porta 80 passa a apenas
  redirecionar (301) para HTTPS;
- **sem certificado** — a porta 80 entrega o trafego direto ao target group. O
  trafego trafega em texto puro, entao esse modo vale so ate o dominio e o
  certificado existirem.

`target_type = "ip"` e o exigido por tasks ECS em modo `awsvpc`: os alvos sao os
ENIs das tasks, registrados e removidos pelo proprio servico ECS — o modulo nao cria
`aws_lb_target_group_attachment`.

O target group usa `create_before_destroy`, porque ele nao pode ser destruido
enquanto um listener o referencia. `name` fica limitado a 29 caracteres: o sufixo
`-tg` do target group ocupa o resto do limite de 32 da AWS.

```hcl
module "alb" {
  source = "./modules/elb"

  name   = "urlshortener-ecs"
  vpc_id = module.vpc.vpc_id

  subnets            = module.vpc.public_subnet_ids
  security_group_ids = [module.sg_alb.id]

  target_type = "ip"
  target_port = 8080

  health_check = {
    path    = "/health"
    matcher = "200"
  }
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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Nome do load balancer. Tambem prefixa target group e listeners. | `string` | n/a | yes |
| security\_group\_ids | Security groups associados ao load balancer. | `list(string)` | n/a | yes |
| subnets | Subnets do load balancer, ao menos duas em AZs diferentes. Publicas para ALB internet-facing. | `list(string)` | n/a | yes |
| vpc\_id | Id da VPC onde o target group e criado. | `string` | n/a | yes |
| access\_logs\_bucket | Bucket S3 dos access logs. O bucket precisa existir antes e ter policy<br/>permitindo escrita pelo servico de log da AWS — o modulo nao cria nenhum dos<br/>dois. Deixe null para nao habilitar. | `string` | `null` | no |
| access\_logs\_prefix | Prefixo das chaves dos access logs dentro do bucket. | `string` | `null` | no |
| certificate\_arn | ARN do certificado ACM. Com certificado, sobe um listener HTTPS na 443 e a<br/>porta 80 passa a apenas redirecionar. Sem certificado, a porta 80 entrega o<br/>trafego direto ao target group — o trafego trafega em texto puro, entao vale<br/>so ate o dominio e o certificado existirem. | `string` | `null` | no |
| deregistration\_delay | Segundos que o LB espera antes de remover um alvo, para drenar conexoes abertas. | `number` | `30` | no |
| drop\_invalid\_header\_fields | Descarta headers HTTP malformados antes de repassar ao alvo. | `bool` | `true` | no |
| enable\_deletion\_protection | Bloqueia a exclusao do load balancer pela API. | `bool` | `false` | no |
| health\_check | Health check do target group. O alvo so recebe trafego depois de healthy\_threshold respostas boas. | <pre>object({<br/>    path                = optional(string, "/")<br/>    port                = optional(string, "traffic-port")<br/>    matcher             = optional(string, "200")<br/>    interval            = optional(number, 30)<br/>    timeout             = optional(number, 5)<br/>    healthy_threshold   = optional(number, 3)<br/>    unhealthy_threshold = optional(number, 3)<br/>  })</pre> | `{}` | no |
| idle\_timeout | Segundos que uma conexao ociosa fica aberta. | `number` | `60` | no |
| internal | Com true o load balancer so recebe trafego de dentro da VPC. | `bool` | `false` | no |
| load\_balancer\_type | Tipo do load balancer: application, network ou gateway. | `string` | `"application"` | no |
| ssl\_policy | Politica TLS do listener HTTPS. Ignorada sem certificate\_arn. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| tags | Tags adicionais aplicadas no load balancer, target group e listeners. | `map(string)` | `{}` | no |
| target\_port | Porta em que o container escuta. | `number` | `80` | no |
| target\_protocol | Protocolo usado pelo load balancer para falar com os alvos. | `string` | `"HTTP"` | no |
| target\_type | Tipo de alvo. Tasks ECS em modo awsvpc exigem "ip". | `string` | `"ip"` | no |

## Outputs

| Name | Description |
|------|-------------|
| arn | ARN do load balancer. |
| dns\_name | DNS publico do load balancer — alvo do registro CNAME/alias. |
| http\_listener\_arn | ARN do listener HTTP. |
| https\_listener\_arn | ARN do listener HTTPS, ou null quando nao ha certificado. |
| target\_group\_arn | ARN do target group — e o valor esperado por aws\_ecs\_service.load\_balancer. |
| target\_group\_name | Nome do target group. |
| zone\_id | Zone id do load balancer, usado em alias record do Route 53. |
<!-- END_TF_DOCS -->
