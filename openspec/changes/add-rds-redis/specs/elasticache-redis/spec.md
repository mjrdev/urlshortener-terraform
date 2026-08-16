## Purpose

Cache Redis gerenciado dentro da VPC para o encurtador, compativel com o cliente que a
aplicacao ja usa e no menor porte disponivel, servindo como cache descartavel e nao como
armazenamento duravel.

## ADDED Requirements

### Requirement: Cache Redis gerenciado

O sistema SHALL prover um cache compativel com o protocolo Redis para a aplicacao, com
engine, versao, tipo de no e quantidade de nos parametrizaveis por ambiente.

#### Scenario: Cache disponivel apos o provisionamento

- **WHEN** o provisionamento da infraestrutura termina
- **THEN** existe um cache em estado disponivel
- **AND** o endereco e a porta ficam expostos como saida da infraestrutura

#### Scenario: Padrao de no unico

- **WHEN** o ambiente nao sobrescreve a quantidade de nos
- **THEN** o cache sobe com um unico no, sem replica e sem failover automatico

### Requirement: Compatibilidade com o cliente da aplicacao

O cache SHALL ser alcancavel pela aplicacao usando apenas endereco, porta e, quando
houver, senha — sem exigir modo cluster, sem exigir TLS e sem mudanca no codigo do app.

#### Scenario: Conexao simples e aceita

- **WHEN** a aplicacao conecta informando endereco e porta, sem TLS e sem senha
- **THEN** a conexao e aceita e os comandos do Redis funcionam

#### Scenario: A aplicacao recebe a configuracao pronta

- **WHEN** a task da aplicacao inicia
- **THEN** ela recebe endereco, porta e a indicacao de que TLS esta desligado, sem que
  ninguem precise editar o codigo ou um arquivo dentro da imagem

### Requirement: Isolamento de rede do cache

O cache SHALL ficar em subnets privadas e SHALL aceitar conexao apenas das tasks da
aplicacao.

#### Scenario: Sem exposicao publica

- **WHEN** alguem tenta alcancar o cache de fora da VPC
- **THEN** nao ha caminho de rede ate ele

#### Scenario: Somente as tasks da aplicacao conectam

- **WHEN** uma origem que nao seja o security group das tasks tenta conectar na porta do
  cache
- **THEN** a conexao e recusada

### Requirement: Perda de cache e aceitavel

O cache SHALL ser tratado como descartavel: sua indisponibilidade ou perda de dados NAO
SHALL exigir intervencao manual de recuperacao.

#### Scenario: Recriacao do cache

- **WHEN** o cache e destruido e recriado
- **THEN** a infraestrutura sobe um cache vazio e a aplicacao volta a usa-lo sem passo
  manual
