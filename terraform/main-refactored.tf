# Archivo principal simplificado - Orquesta todos los componentes
# Este archivo reemplaza el main.tf anterior de 1040 líneas

# La configuración de providers, variables y outputs está en archivos separados:
# - providers.tf: Configuración de Terraform y proveedores
# - variables.tf: Variables de entrada y configuración local
# - outputs.tf: Outputs para otros módulos o referencias externas

# Los recursos están organizados por función:
# - vpc.tf: Red y conectividad
# - security.tf: Security Groups 
# - kms.tf: Cifrado y secrets
# - eks.tf: Kubernetes cluster y nodos
# - rds.tf: Base de datos
# - storage.tf: S3 y ECR
# - monitoring.tf: CloudWatch y logging

# Archivos de configuración por ambiente en /environments/
# - development.tfvars
# - staging.tfvars  
# - production.tfvars

# Templates para configuración dinámica en /templates/
# - user_data.sh: Script de inicialización para nodos EKS

# Uso recomendado:
# terraform plan -var-file="environments/production.tfvars"
# terraform apply -var-file="environments/production.tfvars"
