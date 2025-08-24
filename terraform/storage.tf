# Almacenamiento S3 y ECR

# S3 Bucket para contenido de video
resource "aws_s3_bucket" "content" {
  bucket = "${var.project_name}-${var.environment}-content-${random_id.bucket_suffix.hex}"
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-content"
    Purpose = "Video content storage"
  })
}

# Configuración de versionado para S3
resource "aws_s3_bucket_versioning" "content" {
  bucket = aws_s3_bucket.content.id
  versioning_configuration {
    status = var.environment == "production" ? "Enabled" : "Suspended"
  }
}

# Cifrado por defecto para S3
resource "aws_s3_bucket_server_side_encryption_configuration" "content" {
  bucket = aws_s3_bucket.content.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true  # Reducir costos de KMS
  }
}

# Bloquear acceso público por defecto
resource "aws_s3_bucket_public_access_block" "content" {
  bucket = aws_s3_bucket.content.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle para gestión automática de costos
resource "aws_s3_bucket_lifecycle_configuration" "content" {
  bucket = aws_s3_bucket.content.id
  
  rule {
    id     = "content_lifecycle"
    status = "Enabled"
    
    # Transición a IA después de 30 días
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    # Transición a Glacier después de 90 días
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    # Eliminar versiones antiguas después de 365 días
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# ECR Repository para imágenes Docker
resource "aws_ecr_repository" "main" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  
  # Escaneo de vulnerabilidades
  image_scanning_configuration {
    scan_on_push = true
  }
  
  # Cifrado
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ecr"
  })
}

# Política de lifecycle para ECR
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 development images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
