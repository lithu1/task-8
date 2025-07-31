
# This file includes ECS Cluster, ALB, Task Definition, Service, Log Group, CloudWatch alarms and dashboard.

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}-cluster-${local.suffix}"
}

# ALB SG
resource "aws_security_group" "alb_sg" {
  name        = "${var.app_name}-alb-sg-${local.suffix}"
  description = "Allow HTTP to ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS SG
resource "aws_security_group" "ecs_sg" {
  name        = "${var.app_name}-ecs-sg-${local.suffix}"
  description = "Allow traffic from ALB to ECS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 1337
    to_port         = 1337
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB and Target Group
resource "aws_lb" "this" {
  name               = "${var.app_name}-alb-${local.suffix}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.unique_subnets
}

resource "aws_lb_target_group" "this" {
  name        = "${var.app_name}-tg-${local.suffix}"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.app_name}-${local.suffix}"
  retention_in_days = 7
}

# Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.app_name}-task-${local.suffix}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.task_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name         = var.app_name
    image        = var.image_url
    portMappings = [{ containerPort = 1337, hostPort = 1337 }]
    essential    = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = "${var.app_name}-service-${local.suffix}"
  cluster         = aws_ecs_cluster.this.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1

  network_configuration {
    subnets          = local.unique_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.app_name
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.http]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.app_name}-high-cpu-${local.suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm if ECS CPU > 80%"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.this.name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.app_name}-high-memory-${local.suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm if ECS Memory > 80%"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.this.name
  }
}

# Dashboard
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.app_name}-dashboard-${local.suffix}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x = 0,
        y = 0,
        width = 12,
        height = 6,
        properties = {
          title  = "CPU Utilization",
          view   = "timeSeries",
          region = var.region,
          metrics = [
            [ "AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.this.name, "ServiceName", aws_ecs_service.this.name ]
          ]
        }
      },
      {
        type = "metric",
        x = 0,
        y = 6,
        width = 12,
        height = 6,
        properties = {
          title  = "Memory Utilization",
          view   = "timeSeries",
          region = var.region,
          metrics = [
            [ "AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.this.name, "ServiceName", aws_ecs_service.this.name ]
          ]
        }
      }
    ]
  })
}
