# Infraestructura como Código para Plataforma VOD
# Configuración principal de Terraform

terraform {
  # Versión mínima requerida de Terraform
  required_version = ">= 1.5"
  
  # Configuración del backend remoto para state compartido
  backend "s3" {
    bucket         = "vod-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"  # Para locking del state
    
    # Versionado del state para rollbacks
    versioning = true
  }
  
  # Proveedores requeridos con versiones específicas
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Configuración del proveedor AWS
provider "aws" {
  region = var.aws_region
  
  # Tags por defecto para todos los recursos
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

# Data sources para información existente
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Generar password aleatorio para RDS
resource "random_password" "rds_password" {
  length  = 16
  special = true
}

# Sufijo aleatorio para buckets S3 (nombres globalmente únicos)
resource "random_id" "bucket_suffix" {
  byte_length = 4
}
