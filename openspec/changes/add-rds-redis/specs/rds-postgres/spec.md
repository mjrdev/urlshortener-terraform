## Purpose

Banco Postgres gerenciado para o encurtador, isolado nas subnets privadas da VPC e
dimensionado para o menor custo que ainda entrega um banco duravel, com a credencial
gerada pela infraestrutura e nunca escrita em arquivo versionado.

## ADDED Requirements

### Requirement: Instancia Postgres gerenciada

O sistema SHALL prover uma instancia RDS Postgres para a aplicacao, com engine, versao,
classe de instancia, storage e nome do banco parametrizaveis por ambiente.

#### Scenario: Banco disponivel apos o provisionamento

- **WHEN** o provisionamento da infraestrutura termina
- **THEN** existe uma instancia Postgres em estado `available`
- **AND** o endpoint e o nome do banco ficam expostos como saida da infraestrutura para
  quem precisa liga-los na aplicacao

#### Scenario: Dimensionamento vem do ambiente

- **WHEN** um ambiente define classe de instancia e tamanho de storage diferentes
- **THEN** a instancia e criada com esses valores, sem alteracao no modulo

### Requirement: Isolamento de rede do banco

O banco SHALL ser inalcancavel a partir da internet e SHALL aceitar conexao apenas das
tasks da aplicacao.

#### Scenario: Sem endereco publico

- **WHEN** alguem resolve o endpoint do banco de fora da VPC
- **THEN** nao ha rota nem endereco publico para alcanca-lo

#### Scenario: Somente as tasks da aplicacao conectam

- **WHEN** uma origem que nao seja o security group das tasks tenta abrir conexao na porta
  do Postgres
- **THEN** a conexao e recusada pelo security group do banco

#### Scenario: A aplicacao conecta

- **WHEN** uma task da aplicacao abre conexao no endpoint do banco
- **THEN** a conexao e aceita

### Requirement: Credencial gerada e protegida

A senha do usuario master SHALL ser gerada pela infraestrutura e NAO SHALL aparecer em
arquivo versionado, em log de pipeline nem em saida de infraestrutura legivel.

#### Scenario: Senha ausente do repositorio

- **WHEN** alguem inspeciona os arquivos versionados do repositorio, inclusive os tfvars
- **THEN** nenhuma senha de banco aparece

#### Scenario: Saida nao vaza a senha

- **WHEN** as saidas da infraestrutura sao impressas por uma pipeline
- **THEN** o endpoint aparece e a senha nao

### Requirement: Perfil de custo minimo por padrao

O banco SHALL ter, por padrao, a configuracao mais barata que entrega o servico:
instancia burstable de menor porte, storage minimo, uma unica zona de disponibilidade,
retencao de backup minima e recursos pagos de observabilidade desligados.

#### Scenario: Padroes economicos

- **WHEN** o ambiente nao sobrescreve nenhum parametro de dimensionamento
- **THEN** o banco sobe Single-AZ, sem replica de leitura e sem Performance Insights

#### Scenario: Alta disponibilidade e uma escolha explicita

- **WHEN** um ambiente pede Multi-AZ
- **THEN** o modulo aceita a configuracao, sem que isso vire o padrao dos demais ambientes

### Requirement: Ambiente descartavel

A destruicao do ambiente SHALL ser possivel sem intervencao manual, coerente com o
tratamento de ambiente descartavel ja adotado no projeto.

#### Scenario: Destroy nao trava

- **WHEN** o fluxo de destruicao da infraestrutura roda
- **THEN** a instancia e removida sem exigir desligar protecao ou nomear snapshot final
