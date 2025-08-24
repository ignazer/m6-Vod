# Recursos de cifrado y seguridad

# KMS Key para cifrado
resource "aws_kms_key" "main" {
  description             = "${var.project_name}-${var.environment} encryption key"
  deletion_window_in_days = 7  # Período de gracia antes de eliminación permanente
  
  # Política de acceso a la clave
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-key"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# Secret Manager para credenciales de RDS
resource "aws_secretsmanager_secret" "database" {
  name        = "${var.project_name}/${var.environment}/database"
  description = "Database credentials for ${var.project_name} ${var.environment}"
  kms_key_id  = aws_kms_key.main.key_id
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-secret"
  })
}

# Configuración de rotación automática (opcional)
resource "aws_secretsmanager_secret_rotation" "database" {
  secret_id           = aws_secretsmanager_secret.database.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn  # Requerirá Lambda function para rotación
  
  rotation_rules {
    automatically_after_days = 30
  }
  
  # Comentado por defecto - descomentar solo si se tiene Lambda de rotación
  count = 0
}

# Versión del secreto con las credenciales
resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.rds_password.result
    engine   = "mysql"
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}
