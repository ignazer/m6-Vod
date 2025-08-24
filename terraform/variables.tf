# Variables de entrada principales

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "vod-platform"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Cambiar en producción por IPs específicas
}

# Variables específicas por ambiente
variable "cluster_config" {
  description = "EKS cluster configuration per environment"
  type = map(object({
    node_groups = map(object({
      instance_types = list(string)
      min_size      = number
      max_size      = number
      desired_size  = number
    }))
    cluster_version = string
  }))
  
  default = {
    development = {
      cluster_version = "1.28"
      node_groups = {
        general = {
          instance_types = ["t3.medium"]
          min_size      = 1
          max_size      = 3
          desired_size  = 2
        }
      }
    }
    staging = {
      cluster_version = "1.28"
      node_groups = {
        general = {
          instance_types = ["t3.large"]
          min_size      = 2
          max_size      = 6
          desired_size  = 3
        }
        compute = {
          instance_types = ["c5.xlarge"]
          min_size      = 1
          max_size      = 5
          desired_size  = 2
        }
      }
    }
    production = {
      cluster_version = "1.28"
      node_groups = {
        general = {
          instance_types = ["t3.large", "t3.xlarge"]  # Mixed instances para optimización
          min_size      = 3
          max_size      = 20
          desired_size  = 5
        }
        compute = {
          instance_types = ["c5.xlarge", "c5.2xlarge"]
          min_size      = 2
          max_size      = 30
          desired_size  = 8
        }
        gpu = {
          instance_types = ["p3.2xlarge"]
          min_size      = 0
          max_size      = 5
          desired_size  = 1
        }
      }
    }
  }
}

# Variables locales para cálculos complejos
locals {
  # Tags comunes para todos los recursos
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
  
  # Configuración por ambiente
  env_config = {
    development = {
      rds_instance_class = "db.t3.micro"
      rds_allocated_storage = 20
      rds_max_allocated_storage = 100
      backup_retention_period = 1
      multi_az = false
      deletion_protection = false
      log_retention_days = 7
    }
    staging = {
      rds_instance_class = "db.t3.small"
      rds_allocated_storage = 50
      rds_max_allocated_storage = 500
      backup_retention_period = 3
      multi_az = false
      deletion_protection = false
      log_retention_days = 30
    }
    production = {
      rds_instance_class = "db.r6g.large"
      rds_allocated_storage = 100
      rds_max_allocated_storage = 1000
      backup_retention_period = 7
      multi_az = true
      deletion_protection = true
      log_retention_days = 365
    }
  }
  
  # Subredes calculadas
  public_subnets = [
    for i in range(3) : "10.0.${100 + i}.0/24"
  ]
  
  private_app_subnets = [
    for i in range(3) : "10.0.${10 + i}.0/24"
  ]
  
  private_data_subnets = [
    for i in range(3) : "10.0.${20 + i}.0/24"
  ]
}
