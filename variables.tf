variable "openstack_user_name" {
    description = "The username for the Tenant."
}

variable "PASSWORD" {
    description = "The user password."
}

variable "openstack_tenant_name" {
    description = "The name of the Tenant."
}

variable "openstack_auth_url" {
    description = "The endpoint url to connect to OpenStack."
}

variable "openstack_keypair" {
    description = "The keypair to be used."
}

variable "openstack_network_name" {
  description = "Name of the OpenStack network to attach the instance to"
  type        = string
}

variable "openstack_security_groups" {
  description = "List of security groups to assign to instances"
  type        = list(string)
  default     = ["default"]
}