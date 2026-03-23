provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

# --- VPC: 2 public subnets + 2 private subnets + NAT ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]
  private_subnets = [cidrsubnet(var.vpc_cidr, 8, 11), cidrsubnet(var.vpc_cidr, 8, 12)]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# --- Security group for ALB (internet-facing) ---
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Security group for EC2 (only ALB can reach app port) ---
resource "aws_security_group" "ec2" {
  name        = "${var.name}-ec2-sg"
  description = "EC2 security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "App traffic from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_ingress_cidrs) > 0 ? [1] : []
    content {
      description = "SSH from restricted CIDRs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_ingress_cidrs
    }
  }

  egress {
    description = "All egress (apt + docker pull)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Latest Ubuntu 22.04 AMI ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# --- EC2 instance in PRIVATE subnet ---
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2.id]

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    app_port = var.app_port
  })

  tags = {
    Name = "${var.name}-app"
  }
}

# --- ALB (public) + target group points to EC2 ---
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.7"

  name            = "${var.name}-alb"
  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.alb.id]
  enable_deletion_protection = false

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate_validation.demo.certificate_arn

      forward = {
        target_group_key = "app"
      }
    }
  }

  # Define target group WITHOUT targets; attach via additional_target_group_attachments
  target_groups = {
    app = {
      backend_protocol  = "HTTP"
      backend_port      = var.app_port
      target_type       = "instance"
      create_attachment = false

      health_check = {
        path                = var.healthcheck_path
        protocol            = "HTTP"
        port                = "traffic-port"
        matcher             = "200-399"
        interval            = 30
        timeout             = 10
        healthy_threshold   = 3
        unhealthy_threshold = 3
      }
    }
  }

  additional_target_group_attachments = {
    app_ec2 = {
      target_group_key = "app"
      target_id        = aws_instance.app.id
      port             = var.app_port
    }
  }
}

locals {
  fqdn = var.record_name == "" ? var.domain_name : "${var.record_name}.${var.domain_name}"
}

resource "aws_route53_record" "alb_alias" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "demo" {
  domain_name       = local.fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.demo.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "demo" {
  certificate_arn         = aws_acm_certificate.demo.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}