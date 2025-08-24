# Infraestructura como Código para Plataforma VOD
# Archivo: main.tf

terraform {
  # Versión mínima requerida de Terraform
  required_version = ">= 1.5"
  
  # Para demo - backend local (comentar para producción real)
  # backend "s3" {
  #   bucket         = "vod-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-locks"
  # }
  
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

# Variables de entrada
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

# Generar password aleatorio para RDS
resource "random_password" "rds_password" {
  length  = 16
  special = true
}

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
  
  tags = {
    Name = "${var.project_name}-${var.environment}-key"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# Data source para obtener información de la cuenta
data "aws_caller_identity" "current" {}

# VPC Principal
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Subredes públicas (una por AZ)
resource "aws_subnet" "public" {
  count = 3  # 3 AZs para alta disponibilidad
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${100 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Type = "public"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
    "kubernetes.io/role/elb" = "1"  # Para ALB/NLB
  }
}

# Subredes privadas para aplicaciones
resource "aws_subnet" "private_app" {
  count = 3
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${10 + count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-private-app-${count.index + 1}"
    Type = "private-app"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
    "kubernetes.io/role/internal-elb" = "1"  # Para internal load balancers
  }
}

# Subredes privadas para bases de datos
resource "aws_subnet" "private_data" {
  count = 3
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${20 + count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-private-data-${count.index + 1}"
    Type = "private-data"
  }
}

# Elastic IPs para NAT Gateways
resource "aws_eip" "nat" {
  count = 3  # Un NAT Gateway por AZ para alta disponibilidad
  
  domain = "vpc"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways para conectividad saliente desde subredes privadas
resource "aws_nat_gateway" "main" {
  count = 3
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# Route table para subredes públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

# Asociaciones de route table para subredes públicas
resource "aws_route_table_association" "public" {
  count = 3
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route tables para subredes privadas de aplicación (una por AZ)
resource "aws_route_table" "private_app" {
  count = 3
  
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-private-app-rt-${count.index + 1}"
  }
}

# Asociaciones para subredes privadas de aplicación
resource "aws_route_table_association" "private_app" {
  count = 3
  
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# Route table para subredes de datos (sin acceso a internet)
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-private-data-rt"
  }
}

# Asociaciones para subredes de datos
resource "aws_route_table_association" "private_data" {
  count = 3
  
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}

# Security Group para ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

# Security Group para EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.project_name}-${var.environment}-eks-cluster"
  vpc_id      = aws_vpc.main.id
  
  # Permitir comunicación HTTPS desde nodos worker
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
    description     = "HTTPS from worker nodes"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
  }
}

# Security Group para nodos EKS
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-eks-nodes"
  vpc_id      = aws_vpc.main.id
  
  # Comunicación entre nodos
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "Node-to-node communication"
  }
  
  # Comunicación desde ALB
  ingress {
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "NodePort services from ALB"
  }
  
  # HTTPS hacia cluster
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
    description     = "HTTPS to cluster"
  }
  
  # Todo el tráfico saliente para descargas
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-eks-nodes-sg"
  }
}

# Security Group para RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
    description     = "MySQL from EKS nodes"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

# IAM Role para EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Políticas para el cluster EKS
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# IAM Role para nodos EKS
resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-${var.environment}-eks-nodes-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Políticas para nodos EKS
resource "aws_iam_role_policy_attachment" "eks_nodes_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# Política personalizada para acceso a S3 y otros servicios AWS
resource "aws_iam_role_policy" "eks_nodes_additional" {
  name = "${var.project_name}-${var.environment}-eks-nodes-additional"
  role = aws_iam_role.eks_nodes.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.content.arn}",
          "${aws_s3_bucket.content.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.database.arn,
          "${aws_secretsmanager_secret.database.arn}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_config[var.environment].cluster_version
  
  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private_app[*].id)
    endpoint_private_access = true
    endpoint_public_access  = var.environment == "production" ? false : true  # Solo acceso privado en producción
    public_access_cidrs     = var.environment == "production" ? [] : ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }
  
  # Logging del cluster
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Cifrado de secretos en etcd
  encryption_config {
    provider {
      key_arn = aws_kms_key.main.arn
    }
    resources = ["secrets"]
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster
  ]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster"
  }
}

# CloudWatch Log Group para EKS
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.project_name}-${var.environment}/cluster"
  retention_in_days = var.environment == "production" ? 365 : 30
  kms_key_id        = aws_kms_key.main.arn
  
  tags = {
    Name = "${var.project_name}-${var.environment}-eks-logs"
  }
}

# Node Groups para EKS
resource "aws_eks_node_group" "main" {
  for_each = var.cluster_config[var.environment].node_groups
  
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${each.key}-${var.environment}"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private_app[*].id
  
  instance_types = each.value.instance_types
  capacity_type  = "ON_DEMAND"  # Cambiar a "SPOT" para ahorrar costos en dev/staging
  
  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }
  
  update_config {
    max_unavailable_percentage = 25  # Máximo 25% de nodos indisponibles durante updates
  }
  
  # Configuración de instancias
  remote_access {
    ec2_ssh_key               = aws_key_pair.eks.key_name
    source_security_group_ids = [aws_security_group.bastion.id]  # Solo acceso desde bastion
  }
  
  # User data para configuración personalizada
  launch_template {
    id      = aws_launch_template.eks_nodes[each.key].id
    version = aws_launch_template.eks_nodes[each.key].latest_version
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_worker_policy,
    aws_iam_role_policy_attachment.eks_nodes_cni_policy,
    aws_iam_role_policy_attachment.eks_nodes_registry_policy,
  ]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}-nodes"
    "kubernetes.io/cluster/${aws_eks_cluster.main.name}" = "owned"
  }
}

# Key Pair para acceso SSH a nodos
resource "aws_key_pair" "eks" {
  key_name   = "${var.project_name}-${var.environment}-eks-nodes"
  public_key = file("~/.ssh/id_rsa.pub")  # Ruta a tu clave pública SSH
  
  tags = {
    Name = "${var.project_name}-${var.environment}-eks-keypair"
  }
}

# Launch Templates para nodos EKS
resource "aws_launch_template" "eks_nodes" {
  for_each = var.cluster_config[var.environment].node_groups
  
  name_prefix   = "${var.project_name}-${var.environment}-${each.key}-"
  image_id      = data.aws_ami.eks_worker.id
  instance_type = each.value.instance_types[0]  # Tipo por defecto
  
  vpc_security_group_ids = [aws_security_group.eks_nodes.id]
  
  # Configuración de almacenamiento
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.key == "gpu" ? 100 : 50  # Mayor almacenamiento para nodos GPU
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.main.arn
      delete_on_termination = true
    }
  }
  
  # Configuración de red
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups            = [aws_security_group.eks_nodes.id]
  }
  
  # User data para configuración inicial
  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    cluster_name = aws_eks_cluster.main.name
    node_group   = each.key
    environment  = var.environment
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-${each.key}-node"
      NodeGroup = each.key
    }
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}-template"
  }
}

# AMI para nodos EKS
data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_config[var.environment].cluster_version}-v*"]
  }
  
  most_recent = true
  owners      = ["602401143452"]  # Amazon EKS AMI Account ID
}

# Security Group para Bastion Host
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.environment == "production" ? var.allowed_ssh_cidrs : ["0.0.0.0/0"]
    description = "SSH access"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

# S3 Bucket para contenido de video
resource "aws_s3_bucket" "content" {
  bucket = "${var.project_name}-${var.environment}-content-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-content"
    Purpose = "Video content storage"
  }
}

# Sufijo aleatorio para buckets S3 (nombres globalmente únicos)
resource "random_id" "bucket_suffix" {
  byte_length = 4
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

# Subnet Group para RDS
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private_data[*].id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-db"
  
  # Configuración de la instancia
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.environment == "production" ? "db.r6g.large" : "db.t3.micro"
  
  # Almacenamiento
  allocated_storage     = var.environment == "production" ? 100 : 20
  max_allocated_storage = var.environment == "production" ? 1000 : 100
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
  backup_retention_period = var.environment == "production" ? 7 : 1
  backup_window          = "03:00-04:00"  # UTC
  maintenance_window     = "sun:04:00-sun:05:00"  # UTC
  
  # Configuraciones adicionales
  skip_final_snapshot       = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null
  deletion_protection      = var.environment == "production"
  
  # Multi-AZ para producción
  multi_az = var.environment == "production"
  
  # Logging
  enabled_cloudwatch_logs_exports = ["error", "general", "slow"]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db"
  }
}

# Secret Manager para credenciales de RDS
# Secret Manager para credenciales de RDS
resource "aws_secretsmanager_secret" "database" {
  name        = "${var.project_name}/${var.environment}/database"
  description = "Database credentials for ${var.project_name} ${var.environment}"
  kms_key_id  = aws_kms_key.main.key_id
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-secret"
  }
}

# Configuración de rotación automática (comentado - requiere Lambda)
# resource "aws_secretsmanager_secret_rotation" "database" {
#   secret_id           = aws_secretsmanager_secret.database.id
#   rotation_lambda_arn = aws_lambda_function.rotation.arn
#   
#   rotation_rules {
#     automatically_after_days = 30
#   }
# }

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
  
  tags = {
    Name = "${var.project_name}-${var.environment}-ecr"
  }
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

# Outputs importantes
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

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

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "s3_content_bucket" {
  description = "S3 bucket for content storage"
  value       = aws_s3_bucket.content.bucket
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.main.key_id
}

# CloudWatch Log Groups para aplicaciones
resource "aws_cloudwatch_log_group" "applications" {
  for_each = toset(["api", "frontend", "streaming", "transcoding"])
  
  name              = "/aws/containerinsights/${aws_eks_cluster.main.name}/${each.key}"
  retention_in_days = var.environment == "production" ? 90 : 7
  kms_key_id        = aws_kms_key.main.arn
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-logs"
    Application = each.key
  }
}