
provider "aws" {
  region = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  unique_subnets = slice(distinct([
    for subnet_id in data.aws_subnets.default.ids : subnet_id
  ]), 0, 2)

  suffix = random_id.suffix.hex
}
