/*==== Variable declerations ======*/

variable "project" {

  default     = "swiggy"
  description = "Name of the project"
}

variable "instance_type" {}

variable "instance_ami" {}

variable "cidr_vpc" {}

variable "environment" {}

variable "region" {

  default     = "ap-south-1"
  description = "Region: Mumbai"
}

variable "access_key" {

  default     = "AKIAVMDQREWV2AMXBIA7"
  description = "access key of the provider"
}

variable "secret_key" {

  default     = "IpM31fx/SXy/38Dj9O+Jw8SfoDAfd0wD8N0DuY0Z"
  description = "secret key of the provider"
}



variable "owner" {

  default = "pratheesh"
}

variable "application" {

  default = "food-order"
}

variable "public_domain" {
  
  default = "pratheeshsatheeshkumar.tech"
}
variable "private_domain" {
  
  default = "pratheeshsatheeshkumar.local"
}



locals {
  common_tags = {
    project     = var.project
    environment = var.environment
    owner       = var.owner
    application = var.application
  }
}



locals {
  subnets = length(data.aws_availability_zones.available_azs.names)
}