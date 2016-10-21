variable "access_key" {
  description = "The AWS access key."
}

variable "secret_key" {
  description = "The AWS secret key."
}

variable "region" {
  description = "The region to create resources."
  default     = "us-east-1"
}

variable "namespace" {
  description = "In case running multiple demos."
}

variable "cidr_block" {
  default = "10.1.0.0/16"
}

variable "vault_address" {
  description = "The address where Vault will reside"
  default     = "vault.demo"
}

variable "vault_version" {
  description = "The version of Vault to install (server and client)"
  default     = "0.6.2"
}
