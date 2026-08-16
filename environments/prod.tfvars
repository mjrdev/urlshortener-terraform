# Ambiente: prod
#
# Este arquivo e versionado e guarda apenas configuracao — nada de segredo.
# `app_repository` e `terraform_repository` sao sensitive e continuam vindo do CI
# como TF_VAR_app_repository / TF_VAR_terraform_repository.
#
#   terraform init -input=false -backend-config=environments/prod.backend.hcl
#   terraform plan -var-file=environments/prod.tfvars

region = "us-east-1"
name   = "urlshortener"

##########################
# Rede
##########################

vpc_cidr = "10.0.0.0/16"

# Um NAT so para as tres AZs: mais barato, ao custo de virar ponto unico de falha
# para a saida das subnets privadas.
single_nat_gateway = true
subnet_count       = 3

##########################
# Aplicacao
##########################

app_port              = 8080
app_health_check_path = "/health"

# Tag usada apenas na primeira revisao da task definition; os deploys seguintes
# vem da pipeline da aplicacao.
app_image_tag = "latest"

app_cpu           = 256
app_memory        = 512
app_desired_count = 1

# 4 e o valor hoje aplicado em prod (o CI nunca passou esta variavel, entao valeu
# o default do root). O terraform.tfvars local dizia 2 — se 2 for a intencao,
# mudar aqui vira uma alteracao deliberada, visivel no plan.
app_max_capacity = 4

##########################
# Banco de dados
##########################

# Perfil de custo minimo: burstable menor, storage minimo do gp3 e Single-AZ (o
# modulo ja tem Multi-AZ e Performance Insights desligados por padrao).
db_name           = "urlshortener"
db_username       = "postgres"
db_engine_version = "17"

db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20

##########################
# Cache
##########################

# No unico, sem replica e sem TLS — o isolamento vem do security group.
redis_node_type      = "cache.t4g.micro"
redis_engine_version = "8.0"
