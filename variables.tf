###
# Cluster
##
variable "cluster_name" {}

variable "cluster_dns" {}

variable "version" {
  default = "v1.6.7"
}

variable "master_register_schedulable" {
  default = "false"
}

variable "service_node_port_range" {
  default = "30000-32767"
}

variable "min_nodes_count" {
  default = 1
}

variable "max_nodes_count" {
  default = 2
}

###
# VPC Networking
##

variable "vpc_id" {}

variable "aws_az" {}

variable "public_cidr_block" {}

variable "private_cidr_block" {}

variable "nat_internet_gateway" {}

variable "propagating_vgws" {
  type    = "list"
  default = []
}

variable "whitelisted_ips" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

###
# EC2
##

variable "apiserver_bind_port" {
  default = 6443
}

variable "keypair" {}

variable "additional_security_groups" {
  type    = "list"
  default = []
}

###
# Master
##
variable "master_instance_type" {
  default = "m3.medium"
}

variable "master_disk_size" {
  default = 16
}

###
# Nodes
##
variable "nodes_instance_type" {
  default = "m4.large"
}

variable "nodes_disk_size" {
  default = 32
}
