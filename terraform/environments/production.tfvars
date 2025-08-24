# Configuración para ambiente de producción
environment = "production"
aws_region  = "us-east-1"
project_name = "vod-platform"

# VPC específica para producción
vpc_cidr = "10.2.0.0/16"

# IPs autorizadas para SSH (muy restringido)
allowed_ssh_cidrs = [
  "203.0.113.0/24",  # Oficina principal
  "198.51.100.0/24"  # VPN corporativa
]
