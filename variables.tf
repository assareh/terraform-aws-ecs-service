#############################
## Application - Variables ##
#############################

variable "docker_image" {
  type        = string
  description = "Provide the Docker image to deploy"
}

variable "environment" {
  type        = string
  description = "This variable defines the environment to be built"
}

variable "name" {
  type        = string
  description = "This variable defines the application name used to build resources"
}

variable "subnet_id" {
  type = string
  description = "ID of the subnet where the resources will be created"
}

variable "vpc_id" {
  type = string
  description = "ID of the VPC where the resources will be created"
}
