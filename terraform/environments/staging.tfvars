# Configuración para ambiente de staging
environment = "staging"
aws_region  = "us-east-1"
project_name = "vod-platform"

# VPC específica para staging
vpc_cidr = "10.1.0.0/16"

# IPs autorizadas para SSH (restringido a oficina)
allowed_ssh_cidrs = ["203.0.113.0/24"]  # Cambiar por IP real de oficina
