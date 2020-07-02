locals {
  name_prefix      = "bekk-idrett"
  env              = "prod"
  hosted_zone_name = "${local.name_prefix}.bekk.no"
  region           = "eu-west-1"
  env_domain_name  = "idrett.bekk.no"
}

provider "aws" {
  version = "2.65.0"
  region  = local.region
}

module "bekk-idrett-prod" {
  source = "../common"
  tags = {
    terraform   = "true"
    environment = local.env
    application = local.name_prefix
  }
  hosted_zone_name = local.hosted_zone_name
  name_prefix      = local.name_prefix
  env_domain_name  = local.env_domain_name
}
