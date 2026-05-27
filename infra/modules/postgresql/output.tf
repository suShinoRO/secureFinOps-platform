output "network_name" {
  value = docker_network.securefinops_network.name
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