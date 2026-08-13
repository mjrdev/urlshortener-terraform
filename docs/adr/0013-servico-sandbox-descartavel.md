# ADR 0013 — Servico sandbox descartavel para validar a plataforma

- **Status:** descontinuado em 2026-08-13
- **Data:** 2026-08-08

> **Descontinuado.** O sandbox cumpriu o papel: cluster, NAT, security groups e
> roles de task foram validados com o nginx antes de existir imagem da aplicacao.
> Com `module.ecs_app` ativo e recebendo o trafego do ALB, `sandbox.tf` foi
> apagado, junto com a variavel `nginx_desired_count` e os `-target` do workflow
> de destroy. O registro fica pelo contexto; para recriar um sandbox, este ADR
> descreve a forma que funcionou — lembrando que o servico novo nao pode dividir
> o target group do app.

## Contexto

Validar cluster, rede, NAT, security groups e roles de task exige subir alguma
coisa no ECS. Usar o servico da aplicacao para isso amarra a validacao da
infraestrutura ao build do app: se a imagem no ECR nao existe ou nao sobe, nao da
para distinguir "a rede esta errada" de "a aplicacao esta quebrada". Alem disso, o
servico da aplicacao nao pode ter ECS Exec ligado por conveniencia de debug.

## Decisao

`sandbox.tf` contem um servico ECS **descartavel**, com nginx da galeria publica
(`public.ecr.aws/nginx/nginx:stable`), separado da aplicacao:

- **Reusa o cluster** de `module.ecs_app` passando `cluster_arn`; nao cria cluster
  proprio.
- **Sem target group**: nao ha rota vinda do ALB. O teste e feito por
  `aws ecs execute-command` ou de dentro da VPC.
- `enable_execute_command = true`, o que faz `modules/ecs` criar tambem a policy
  de `ssmmessages` na task role — sem ela o exec falha mesmo com a flag ligada.
- Security group proprio (`sg_ecs_nginx`), com entrada HTTP so a partir do CIDR da
  VPC.
- `log_retention_in_days = 3`, contra o default do modulo.

O arquivo e autocontido: **nada fora dele depende de nada dentro dele**, e ele pode
ser apagado inteiro. `nginx_desired_count` permite zerar o servico sem remover o
codigo.

## Alternativas consideradas

- **Testar com o proprio servico da aplicacao** — confunde falha de infra com falha
  de build, e exigiria ECS Exec ligado em producao.
- **Cluster ECS separado so para o sandbox** — isolaria mais, mas o ponto e
  justamente validar o cluster que a aplicacao usa.
- **Nada de sandbox, validar pelo console** — sem um servico rodando nao ha o que
  validar quanto a saida pelo NAT, resolucao de DNS e permissao de pull.

## Consequencias

- Da para provar que a plataforma funciona antes de existir imagem da aplicacao.
- **Custa dinheiro enquanto estiver de pe**: uma task Fargate 256/512 e o trafego
  dela pelo NAT. Zerar `nginx_desired_count` quando nao estiver em uso.
- O sandbox exercita o caminho de `cluster_arn` de `modules/ecs`, entao ele tambem
  e a prova de que varios servicos compartilham cluster
  ([ADR-0004](0004-ecs-fargate-atras-de-alb.md)).
- Ao apagar `sandbox.tf`, lembrar de remover os `-target` de `module.ecs_nginx` e
  `module.sg_ecs_nginx` do workflow de destroy
  ([ADR-0008](0008-destroy-seletivo-por-target.md)).
- Ter um servico com ECS Exec habilitado no mesmo cluster amplia a superficie de
  debug — e de acesso. Nao deixar ligado indefinidamente.
