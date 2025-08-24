# Configuración completa de EKS

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
  
  tags = local.common_tags
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
  
  tags = local.common_tags
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

# CloudWatch Log Group para EKS
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.project_name}-${var.environment}/cluster"
  retention_in_days = local.env_config[var.environment].log_retention_days
  kms_key_id        = aws_kms_key.main.arn
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-logs"
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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-cluster"
  })
}

# Key Pair para acceso SSH a nodos
resource "aws_key_pair" "eks" {
  key_name   = "${var.project_name}-${var.environment}-eks-nodes"
  public_key = file("~/.ssh/id_rsa.pub")  # Ruta a tu clave pública SSH
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-keypair"
  })
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
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-${var.environment}-${each.key}-node"
      NodeGroup = each.key
    })
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}-template"
  })
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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}-nodes"
    "kubernetes.io/cluster/${aws_eks_cluster.main.name}" = "owned"
  })
}
