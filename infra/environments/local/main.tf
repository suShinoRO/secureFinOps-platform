terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

module "postgres" {
  source = "../../modules/postgresql"

  environment = "local"
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
  db_port     = 5432
}