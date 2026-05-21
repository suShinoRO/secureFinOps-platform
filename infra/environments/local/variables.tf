variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "transactiondb"
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "securefinops"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}