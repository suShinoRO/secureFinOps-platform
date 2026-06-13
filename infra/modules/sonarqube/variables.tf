variable "environment" {
  type = string
}

variable "sonarqube_port" {
  type    = number
  default = 9000
}

variable "network_name" {
  description = "Docker network for container communication"
  type        = string
}