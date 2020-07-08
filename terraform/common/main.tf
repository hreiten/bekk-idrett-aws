data "aws_availability_zones" "main" {}
data "aws_caller_identity" "current-account" {}
data "aws_region" "current" {}

locals {
  project_bucket = "${var.name_prefix}-${var.env}-pipeline-artifact"

  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  vpc_cidr_block     = "10.0.0.0/16"
  service_port       = 8080
  api_name           = "api"
}

## CREATE VPC AND SUBNETS
module "vpc" {
  source     = "github.com/cloudposse/terraform-aws-vpc.git?ref=b2df4eb"
  namespace  = var.name_prefix
  stage      = var.env
  name       = local.api_name
  cidr_block = local.vpc_cidr_block
  tags       = var.tags
}

module "dynamic_subnets" {
  source             = "github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=7d3182d"
  namespace          = var.name_prefix
  stage              = var.env
  name               = local.api_name
  availability_zones = local.availability_zones
  vpc_id             = module.vpc.vpc_id
  igw_id             = module.vpc.igw_id
  cidr_block         = local.vpc_cidr_block
  tags               = var.tags
}



## CREATE ALB
resource "aws_lb" "alb" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = module.dynamic_subnets.public_subnet_ids
  security_groups    = aws_security_group.alb_sg.*.id
  idle_timeout       = 60

  access_logs {
    bucket  = lookup({}, "bucket", "")
    prefix  = lookup({}, "prefix", null)
    enabled = lookup({}, "enabled", false)
  }

  tags = merge(
    var.tags,
    {
      "Name" = var.name_prefix
    },
  )
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.name_prefix}-sg"
  description = "Terraformed security group."
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    var.tags,
    {
      "Name" = "${var.name_prefix}-sg"
    },
  )
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.alb_sg.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "alb_ingress_443" {
  security_group_id = concat(aws_security_group.alb_sg[*].id, [""])[0]
  type              = "ingress"
  from_port         = "443"
  to_port           = "443"
  protocol          = "tcp"

  cidr_blocks = [
  "0.0.0.0/0"]
  ipv6_cidr_blocks = [
  "::/0"]
}

## CREATE AND REQUEST CERTIFICATE
data "aws_route53_zone" "default" {
  name         = "${var.env_domain_name}."
  private_zone = false
}

module "acm_request_certificate" {
  source                            = "github.com/cloudposse/terraform-aws-acm-request-certificate.git?ref=8bad533"
  domain_name                       = var.env_domain_name
  process_domain_validation_options = true
  ttl                               = "300"
  tags                              = var.tags
  wait_for_certificate_issued       = true
}

## CREATE ALIAS FROM DOMAIN TO ALB
module "production_www" {
  source                 = "github.com/cloudposse/terraform-aws-route53-alias.git?ref=d13bc2d"
  aliases                = [var.env_domain_name]
  parent_zone_id         = data.aws_route53_zone.default.zone_id
  target_dns_name        = aws_lb.alb.dns_name
  target_zone_id         = aws_lb.alb.zone_id
  evaluate_target_health = true
}

## CREATE ALB LISTENERS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = module.acm_request_certificate.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown service"
      status_code  = "404"
    }
  }
}


## CREATE ECS CLUSTER
resource "aws_ecs_cluster" "cluster" {
  name = "${var.name_prefix}-cluster"
}


## CREATE FARGATE SERVICE: API
data "aws_ssm_parameter" "service_version" {
  name = "/${var.name_prefix}/${var.name_prefix}-${local.api_name}/image-sha"
}

module "service" {
  source             = "./fargate_service"
  name_prefix        = "${var.name_prefix}-${local.api_name}"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.dynamic_subnets.public_subnet_ids
  lb_arn             = aws_lb.alb.arn
  cluster_id         = aws_ecs_cluster.cluster.id

  task_container_image = "796694622366.dkr.ecr.eu-west-1.amazonaws.com/${var.name_prefix}-${local.api_name}:${data.aws_ssm_parameter.service_version.value}-SHA1"
  task_container_port  = local.service_port

  health_check = {
    port = local.service_port
    path = "/${local.api_name}/health"
  }

  tags = var.tags
}

resource "aws_security_group_rule" "service_allow_incoming" {
  security_group_id        = module.service.service_sg_id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = local.service_port
  to_port                  = local.service_port
  source_security_group_id = concat(aws_security_group.alb_sg[*].id, [""])[0]
}

resource "aws_lb_listener_rule" "service_lb_listener" {
  listener_arn = aws_lb_listener.https.arn

  action {
    type             = "forward"
    target_group_arn = module.service.target_group_arn
  }

  condition {
    path_pattern {
      values = ["/${local.api_name}/*"]
    }
  }
}
