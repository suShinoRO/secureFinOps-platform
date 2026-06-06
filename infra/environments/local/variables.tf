variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  sensitive   = true
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "jenkins_port"{
  description = "Jenkins port"
  type        = number
  default     = 8081
}