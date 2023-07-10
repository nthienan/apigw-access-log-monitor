variable "aws_region" {
  type = string
  description = "The AWS region where resources created"
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type = list(string)
  description = "Subnet IDs where resources created"
}

variable "private_subnet_ids" {
  type = list(string)
  description = "Subnet IDs where resources created"
}
