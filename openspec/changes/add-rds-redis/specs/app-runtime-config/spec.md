## Purpose

Define o que a task ECS do encurtador recebe em tempo de execucao — variaveis de ambiente
e segredos — para que o processo suba sem depender de nenhum arquivo dentro da imagem e
sem que segredo algum apareca na definicao da task ou no repositorio.

## ADDED Requirements

### Requirement: Configuracao completa via ambiente

A task da aplicacao SHALL receber todas as variaveis que o processo le no boot: porta,
conexao com o banco, conexao com o cache e segredo de assinatura de token.

#### Scenario: Aplicacao sobe sem arquivo de configuracao

- **WHEN** a task inicia a partir da imagem publicada, que nao contem arquivo de ambiente
- **THEN** o processo obtem toda a configuracao do ambiente injetado pela infraestrutura
- **AND** conecta no banco e no cache sem erro

#### Scenario: Endpoints vem da propria infraestrutura

- **WHEN** o endpoint do banco ou do cache muda por recriacao do recurso
- **THEN** a configuracao entregue a task acompanha o valor novo, sem edicao manual

### Requirement: Segredos fora da definicao da task

Senha do banco e segredo de assinatura de token SHALL ser entregues por referencia a um
cofre de parametros, e NAO SHALL aparecer em texto claro na definicao da task, no estado
da infraestrutura exposto a leitura casual, nem em arquivo versionado.

#### Scenario: Inspecao da task definition

- **WHEN** alguem le a definicao da task registrada na nuvem
- **THEN** ve o identificador do parametro, nunca o valor do segredo

#### Scenario: Permissao de leitura minima

- **WHEN** a task inicia
- **THEN** a role de execucao consegue ler exatamente os parametros declarados para ela
- **AND** nao recebe permissao para ler outros parametros da conta

### Requirement: Porta consistente entre aplicacao, container e balanceador

A porta em que a aplicacao escuta SHALL ser a mesma registrada no container, no security
group das tasks e no target group do balanceador.

#### Scenario: Health check aprovado

- **WHEN** a task sobe e o balanceador consulta o caminho de health check
- **THEN** a resposta chega na porta configurada e o alvo passa a `healthy`

#### Scenario: Mudanca de porta em um lugar so

- **WHEN** a porta da aplicacao e alterada na configuracao do ambiente
- **THEN** container, security group e target group passam a usar a porta nova juntos

### Requirement: Fronteira com o deploy da aplicacao

Mudanca de configuracao ou de segredo SHALL ser feita pela infraestrutura, e a promocao da
imagem SHALL continuar sendo da pipeline da aplicacao; nenhum dos dois lados SHALL desfazer
o trabalho do outro.

#### Scenario: Deploy da aplicacao preserva a configuracao

- **WHEN** a pipeline da aplicacao promove uma imagem nova
- **THEN** a revisao publicada mantem as variaveis e os segredos definidos pela
  infraestrutura, trocando apenas a imagem

#### Scenario: Mudanca de configuracao aguarda o proximo deploy

- **WHEN** a infraestrutura altera uma variavel de ambiente da aplicacao
- **THEN** uma revisao nova da definicao da task passa a existir
- **AND** o servico continua rodando a revisao atual ate o proximo deploy da aplicacao
