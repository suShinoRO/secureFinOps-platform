output "sonarqube_url" {
  value = "http://securefinops-sonarqube-${var.environment}:9000"
}

output "container_name" {
  value = docker_container.sonarqube.name
}