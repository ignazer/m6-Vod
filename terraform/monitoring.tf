# CloudWatch Log Groups para aplicaciones y monitoreo

# CloudWatch Log Groups para aplicaciones
resource "aws_cloudwatch_log_group" "applications" {
  for_each = toset(["api", "frontend", "streaming", "transcoding"])
  
  name              = "/aws/containerinsights/${aws_eks_cluster.main.name}/${each.key}"
  retention_in_days = local.env_config[var.environment].log_retention_days
  kms_key_id        = aws_kms_key.main.arn
  
  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-logs"
    Application = each.key
  })
}
