# Configuración para ambiente de desarrollo
environment = "development"
aws_region  = "us-east-1"
project_name = "vod-platform"

# VPC específica para desarrollo
vpc_cidr = "10.0.0.0/16"

# IPs autorizadas para SSH (más permisivo en desarrollo)
allowed_ssh_cidrs = ["0.0.0.0/0"]
