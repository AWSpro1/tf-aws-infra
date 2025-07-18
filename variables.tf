variable "aws_profile" {
  default = "dev"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "environment" {
  default = "dev"
}

variable "app_port" {
  type    = number
  default = 8080
}