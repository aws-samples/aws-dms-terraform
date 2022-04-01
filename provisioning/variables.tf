variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "backend_bucket" {
  type = string
}

variable "common_tags" {
  type = map
}

##################### Source DB VPC

variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "vpc_azs" {
  type = list
}

variable "vpc_public_subnets" {
  type = list
}

variable "vpc_private_subnets" {
  type = list
}


##################### DMS VPC
variable "vpc2_name" {
  type = string
}

variable "vpc2_cidr" {
  type = string
}

variable "vpc2_azs" {
  type = list
}

variable "vpc2_private_subnets" {
  type = list
}

variable "vpc2_public_subnets" {
  type = list
}

##################### Target DB VPC
variable "vpc3_name" {
  type = string
}

variable "vpc3_cidr" {
  type = string
}

variable "vpc3_azs" {
  type = list
}

variable "vpc3_private_subnets" {
  type = list
}

variable "vpc3_public_subnets" {
  type = list
}

######################## Load Balancers
variable "nlb_name" {
  type = string
}

variable "nlb_tg_name" {
  type = string
}



variable "vpc_endpoint_name" {
  type = string
}

variable "vpc_endpoint_service_name" {
  type = string
}

variable "instance_size" {
  type = string
}

########################### Sec Groups


variable "endpoint_sg_name" {
  type = string
}

variable "ssm_sg_name" {
  type = string
}

variable "s3_sg_name" {
  type = string
}








