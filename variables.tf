variable "name" {
  type        = string
  default     = "salt-demo"
  description = "Name prefix for all resources"
}

variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.50.0.0/16"
  description = "VPC CIDR"
}

# REQUIRED: lock down ALB exposure to your IP(s)
variable "allowed_ingress_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the ALB over HTTP"
}

# Optional SSH ingress (note: instance is in a private subnet; SSH needs a bastion/VPN/SSM)
variable "ssh_ingress_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to SSH into EC2 (leave empty to disable SSH ingress)"
}

# Optional: only needed if you actually SSH (and have a route to the private subnet)
variable "ec2_keypair_name" {
  type        = string
  default     = ""
  description = "Existing EC2 Key Pair name (optional)"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type"
}

# IMPORTANT: Must match the container listening port unless you change docker -p mapping.
variable "app_port" {
  type        = number
  description = "Port the app listens on (and ALB forwards to)"
}

variable "healthcheck_path" {
  type        = string
  default     = "/"
  description = "ALB target group health check path"
}

variable "domain_name" { type = string }
variable "record_name" {
  type    = string
  default = "demo" # set "" for apex/root
}

data "aws_route53_zone" "this" {
  name         = "${var.domain_name}."
  private_zone = false
}