variable "db_name" {}
variable "db_user" {}
variable "db_password" {}
variable "db_port" { default = 5432 }
variable "environment" {}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_container" "postgres" {
  name  = "securefinops-postgres-${var.environment}"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
  ]

  ports {
    internal = 5432
    external = var.db_port
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  restart = "unless-stopped"
}

resource "docker_volume" "postgres_data" {
  name = "securefinops-postgres-data-${var.environment}"
}

output "postgres_host" {
  value = "localhost"
}

output "postgres_port" {
  value = var.db_port
}

output "postgres_db" {
  value = var.db_name
}