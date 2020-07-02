variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

variable "env" {
  description = "Name of environment, e.g. prod, test, stage."
  type        = string
  default     = "prod"
}

variable "hosted_zone_name" {
  description = "the hosted zone name for the account (domain)"
  type        = string
}

variable "env_domain_name" {
  description = "Domain name for environment"
  type        = string
}
