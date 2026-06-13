terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "sonarqube" {
  name         = "sonarqube:lts-community"
  keep_locally = true
}

resource "docker_volume" "sonarqube_data" {
  name = "securefinops-sonarqube-data-${var.environment}"
}

resource "docker_volume" "sonarqube_logs" {
  name = "securefinops-sonarqube-logs-${var.environment}"
}

resource "docker_container" "sonarqube" {
  name  = "securefinops-sonarqube-${var.environment}"
  image = docker_image.sonarqube.image_id

  ports {
    internal = 9000
    external = var.sonarqube_port
  }

  volumes {
    volume_name    = docker_volume.sonarqube_data.name
    container_path = "/opt/sonarqube/data"
  }

  volumes {
    volume_name    = docker_volume.sonarqube_logs.name
    container_path = "/opt/sonarqube/logs"
  }

  networks_advanced {
    name = var.network_name
  }

  restart = "unless-stopped"
}