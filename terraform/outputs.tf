# Outputs importantes para otros módulos o referencias externas

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs of the private data subnets"
  value       = aws_subnet.private_data[*].id
}

# EKS Outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "eks_cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "eks_node_groups" {
  description = "EKS node groups information"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      arn           = v.arn
      status        = v.status
      capacity_type = v.capacity_type
      instance_types = v.instance_types
    }
  }
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_secret_arn" {
  description = "ARN of the database secret in Secrets Manager"
  value       = aws_secretsmanager_secret.database.arn
}

# Storage Outputs
output "s3_content_bucket" {
  description = "S3 bucket for content storage"
  value       = aws_s3_bucket.content.bucket
}

output "s3_content_bucket_arn" {
  description = "ARN of the S3 content bucket"
  value       = aws_s3_bucket.content.arn
}

# Container Registry Outputs
output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.main.arn
}

# Security Outputs
output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.main.arn
}

# Network Security Outputs
output "security_groups" {
  description = "Security group IDs"
  value = {
    alb         = aws_security_group.alb.id
    eks_cluster = aws_security_group.eks_cluster.id
    eks_nodes   = aws_security_group.eks_nodes.id
    rds         = aws_security_group.rds.id
    bastion     = aws_security_group.bastion.id
  }
}

# Useful connection information
output "connection_info" {
  description = "Connection information for applications"
  value = {
    environment = var.environment
    region      = var.aws_region
    cluster_name = aws_eks_cluster.main.name
    database_secret_name = aws_secretsmanager_secret.database.name
    ecr_repository = aws_ecr_repository.main.name
    content_bucket = aws_s3_bucket.content.bucket
  }
  sensitive = true
}
