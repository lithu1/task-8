
variable "region" {
  default = "us-east-2"
}

variable "app_name" {
  description = "Application name"
  default     = "strapi"
}

variable "image_url" {
  description = "Docker image URI"
  default     = "607700977843.dkr.ecr.us-east-2.amazonaws.com/strapi-ecr-prod:latest"
}

variable "task_role_arn" {
  description = "IAM role ARN for ECS task"
}
