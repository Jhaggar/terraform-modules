variable "component" {}
variable "highcpu" {}
variable "lowcpu" {}
variable "ami" {}
variable "instance_type" {}
variable "public_key_path" {}
variable "userdata" {}
variable "rds_name" {}
variable "environment" {}
variable "bucket_name" {}
variable "account_id" {}
variable "key_name" {}
variable "branch" {}

variable "vpc_id" {
  type = string
}

variable "subnet_prefix" {
  type = string
}
variable "subnet_prefix_1" {
  type = string
}

variable "subnet_prefix_2" {
  type = string
}

variable "repository_name" {}
variable "repository_owner" {}
variable "github_token" {}
