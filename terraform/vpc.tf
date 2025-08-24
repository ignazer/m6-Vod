# VPC y componentes de red

# VPC Principal
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# Subredes públicas (una por AZ)
resource "aws_subnet" "public" {
  count = 3  # 3 AZs para alta disponibilidad
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Type = "public"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
    "kubernetes.io/role/elb" = "1"  # Para ALB/NLB
  })
}

# Subredes privadas para aplicaciones
resource "aws_subnet" "private_app" {
  count = 3
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_app_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-app-${count.index + 1}"
    Type = "private-app"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
    "kubernetes.io/role/internal-elb" = "1"  # Para internal load balancers
  })
}

# Subredes privadas para bases de datos
resource "aws_subnet" "private_data" {
  count = 3
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_data_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-data-${count.index + 1}"
    Type = "private-data"
  })
}

# Elastic IPs para NAT Gateways
resource "aws_eip" "nat" {
  count = 3  # Un NAT Gateway por AZ para alta disponibilidad
  
  domain = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways para conectividad saliente desde subredes privadas
resource "aws_nat_gateway" "main" {
  count = 3
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# Route table para subredes públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-app-rt-${count.index + 1}"
  })
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
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-data-rt"
  })
}

# Asociaciones para subredes de datos
resource "aws_route_table_association" "private_data" {
  count = 3
  
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}
