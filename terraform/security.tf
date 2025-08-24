# Security Groups para todos los componentes

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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  })
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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
  })
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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-nodes-sg"
  })
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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  })
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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  })
}
