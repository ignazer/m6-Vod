# Base de datos RDS y configuración relacionada

# Subnet Group para RDS
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private_data[*].id
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-db"
  
  # Configuración de la instancia
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = local.env_config[var.environment].rds_instance_class
  
  # Almacenamiento
  allocated_storage     = local.env_config[var.environment].rds_allocated_storage
  max_allocated_storage = local.env_config[var.environment].rds_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.main.arn
  
  # Base de datos
  db_name  = "vodplatform"
  username = "admin"
  password = random_password.rds_password.result
  
  # Red y seguridad
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false
  
  # Backup y mantenimiento
  backup_retention_period = local.env_config[var.environment].backup_retention_period
  backup_window          = "03:00-04:00"  # UTC
  maintenance_window     = "sun:04:00-sun:05:00"  # UTC
  
  # Configuraciones adicionales
  skip_final_snapshot       = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null
  deletion_protection      = local.env_config[var.environment].deletion_protection
  
  # Multi-AZ para producción
  multi_az = local.env_config[var.environment].multi_az
  
  # Logging
  enabled_cloudwatch_logs_exports = ["error", "general", "slow"]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-db"
  })
}
