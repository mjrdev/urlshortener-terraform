# Template para um ambiente novo: copie para environments/<env>.tfvars, ajuste os
# valores e crie o environments/<env>.backend.hcl com uma `key` propria.
#
# As duas variaveis sem default e sem valor aqui — app_repository e
# terraform_repository — sao sensitive: passe por TF_VAR_ (CI) ou por um tfvars
# local nao versionado. Formato do claim `sub` do GitHub OIDC:
# owner@ownerid/repo@repoid.

region = "us-east-1"
name   = "urlshortener-exemplo"

vpc_cidr           = "10.20.0.0/16"
single_nat_gateway = true
subnet_count       = 2

app_port              = 8080
app_health_check_path = "/health"
app_image_tag         = "latest"

app_cpu           = 256
app_memory        = 512
app_desired_count = 1
app_max_capacity  = 2

db_name           = "urlshortener"
db_username       = "postgres"
db_engine_version = "17"

db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20

redis_node_type      = "cache.t4g.micro"
redis_engine_version = "8.0"
