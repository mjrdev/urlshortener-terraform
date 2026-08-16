# Architecture Decision Records

Decisoes de arquitetura desta infraestrutura, uma por arquivo. Cada ADR responde
**por que** a alternativa mais simples foi descartada — o **como** esta no codigo e
nos `README.md` dos modulos.

Ver [ADR-0001](0001-registrar-decisoes-em-adr.md) para o processo. Novo ADR: copie
`template.md`, use o proximo numero livre.

| # | Decisao | Status |
| --- | --- | --- |
| [0001](0001-registrar-decisoes-em-adr.md) | Registrar decisoes de arquitetura em ADRs | aceito |
| [0002](0002-backend-s3-parcial-por-ambiente.md) | Backend S3 parcial com uma key por ambiente | aceito |
| [0003](0003-root-composicional-com-modulos-locais.md) | Root module composicional com modulos locais proprios | aceito |
| [0004](0004-ecs-fargate-atras-de-alb.md) | ECS Fargate em subnets privadas atras de um ALB publico | aceito |
| [0005](0005-deploy-da-aplicacao-fora-do-terraform.md) | O Terraform nao faz deploy da aplicacao | aceito |
| [0006](0006-autenticacao-da-ci-via-github-oidc.md) | Autenticacao da CI na AWS via GitHub OIDC | aceito |
| [0007](0007-prevent-destroy-como-input-de-modulo.md) | `prevent_destroy` como input de modulo, via recursos gemeos | aceito |
| [0008](0008-destroy-seletivo-por-target.md) | Destroy seletivo por `-target`, preservando o acesso da pipeline | aceito |
| [0009](0009-security-groups-por-mapa-de-regras.md) | Security groups com regras declaradas como mapa | aceito |
| [0010](0010-nat-gateway-unico.md) | NAT gateway unico, com HA como opcao de ambiente | aceito |
| [0011](0011-versionamento-de-provider.md) | Versao do provider fixada no root, range aberto nos modulos | aceito |
| [0012](0012-readme-gerado-por-terraform-docs.md) | README de modulo gerado por terraform-docs | aceito |
| [0013](0013-servico-sandbox-descartavel.md) | Servico sandbox descartavel para validar a plataforma | descontinuado |
| [0014](0014-endurecimento-da-pipeline-em-repo-publico.md) | Endurecimento da pipeline em repositorio publico | aceito |
| [0015](0015-dados-gerenciados-na-vpc.md) | Postgres e Redis gerenciados na VPC, no menor porte | aceito |

## Por tema

- **State e ambientes** — [0002](0002-backend-s3-parcial-por-ambiente.md)
- **Organizacao do codigo** — [0003](0003-root-composicional-com-modulos-locais.md), [0011](0011-versionamento-de-provider.md), [0012](0012-readme-gerado-por-terraform-docs.md)
- **Topologia e rede** — [0004](0004-ecs-fargate-atras-de-alb.md), [0009](0009-security-groups-por-mapa-de-regras.md), [0010](0010-nat-gateway-unico.md)
- **Dados e segredos** — [0015](0015-dados-gerenciados-na-vpc.md)
- **Fronteira com a aplicacao** — [0005](0005-deploy-da-aplicacao-fora-do-terraform.md), [0013](0013-servico-sandbox-descartavel.md)
- **Acesso e ciclo de vida** — [0006](0006-autenticacao-da-ci-via-github-oidc.md), [0007](0007-prevent-destroy-como-input-de-modulo.md), [0008](0008-destroy-seletivo-por-target.md), [0014](0014-endurecimento-da-pipeline-em-repo-publico.md)

## Dividas registradas

Pontos que os ADRs reconhecem como pendencia conhecida, nao como estado desejado:

- Escalation dentro do prefixo do projeto continua possivel: falta permissions
  boundary nas roles que a pipeline cria ([0014](0014-endurecimento-da-pipeline-em-repo-publico.md)).
- O `plan` em PR usaria a mesma role de escrita do `apply`; falta uma role
  read-only separada ([0014](0014-endurecimento-da-pipeline-em-repo-publico.md)).
- Trafego de entrada ainda em HTTP; falta `certificate_arn` ([0004](0004-ecs-fargate-atras-de-alb.md)).
- Lista de `-target` do destroy e manual ([0008](0008-destroy-seletivo-por-target.md)).
- Nada forca a regeneracao dos READMEs ([0012](0012-readme-gerado-por-terraform-docs.md)).
- Versao do Terraform vive em `vars.TF_VERSION`, fora do repositorio ([0011](0011-versionamento-de-provider.md)).
- Senha do banco vive no state, e a migracao de schema nao tem dono
  ([0015](0015-dados-gerenciados-na-vpc.md)).
