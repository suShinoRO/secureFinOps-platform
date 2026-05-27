variable "environment" {
  type = string
}

variable "jenkins_port" {
  type    = number
  default = 8081
}

variable "network_name" {
  description = "Docker network for container communication"
  type        = string
}