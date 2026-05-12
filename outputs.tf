output "db_username" {
  description = "The username for the database."
  value       = var.db_username
}

output "db_version" {
  description = "The version of the database."
  value       = var.db_version
}

output "db_dns" {
  description = "The DNS name of the database."
  value       = data.oci_psql_db_system_connection_detail.main.primary_db_endpoint[0].fqdn
}

output "db_system_id" {
  description = "The OCID of the PostgreSQL DB system."
  value       = oci_psql_db_system.main.id
}

output "nsg_id" {
  description = "The OCID of the network security group attached to the DB system."
  value       = oci_core_network_security_group.main.id
}

output "secret_id" {
  description = "The OCID of the vault secret containing the database password."
  value       = oci_vault_secret.main.id
}

