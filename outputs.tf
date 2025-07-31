
output "alb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "Public URL of the Application Load Balancer"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "ECS Cluster Name"
}

output "ecs_service_name" {
  value       = aws_ecs_service.this.name
  description = "ECS Service Name"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.this.name
  description = "CloudWatch Log Group Name"
}
