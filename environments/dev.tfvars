# Ambiente: dev
#
#   terraform init -input=false -reconfigure -backend-config=environments/dev.backend.hcl
#   terraform plan -var-file=environments/dev.tfvars
#
# CIDR diferente do de prod para que um peering futuro entre os dois nao conflite.

region = "us-east-1"
name   = "urlshortener-dev"

##########################
# Rede
##########################

vpc_cidr           = "10.10.0.0/16"
single_nat_gateway = true
subnet_count       = 2

##########################
# Aplicacao
##########################

app_port              = 8080
app_health_check_path = "/health"
app_image_tag         = "latest"

app_cpu           = 256
app_memory        = 512
app_desired_count = 1
app_max_capacity  = 2
