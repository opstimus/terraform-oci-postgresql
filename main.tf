resource "oci_vault_secret" "main" {
  compartment_id = var.compartment_id
  vault_id       = var.kms_vault_id
  key_id         = var.kms_key_id
  secret_name    = "${var.project}-${var.environment}-${var.name}-db-password"
  freeform_tags  = var.tags

  secret_content {
    content_type = "TEXT"
    content      = random_password.main.result
  }
}

resource "random_password" "main" {
  length           = 16
  special          = true
  override_special = "!#$%&*?"
}

resource "oci_core_network_security_group" "main" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "${var.project}-${var.environment}-${var.name}"
  freeform_tags  = var.tags
}


resource "oci_psql_db_system" "main" {
  compartment_id              = var.compartment_id
  display_name                = "${var.project}-${var.environment}-${var.name}"
  db_version                  = var.db_version
  instance_count              = var.instance_count
  shape                       = var.db_system_shape
  instance_memory_size_in_gbs = var.instance_memory_size_in_gbs
  instance_ocpu_count         = var.instance_ocpu_count
  freeform_tags               = var.tags

  credentials {
    password_details {
      password_type  = "VAULT_SECRET"
      secret_id      = oci_vault_secret.main.id
      secret_version = 1
    }
    username = var.db_username
  }

  network_details {
    subnet_id                  = var.subnet_id
    is_reader_endpoint_enabled = var.is_reader_endpoint_enabled
    nsg_ids                    = [oci_core_network_security_group.main.id]
  }

  storage_details {
    is_regionally_durable = true
    system_type           = "OCI_OPTIMIZED_STORAGE"
    iops                  = var.storage_iops
  }

  instances_details {
    display_name = "${var.project}-${var.environment}-${var.name}-node"
  }
  management_policy {
    backup_policy {
      kind           = "DAILY"
      backup_start   = var.backup_start_time
      retention_days = var.backup_retention_days
    }
  }
  source {
    source_type = var.db_source_type
    backup_id   = var.db_source_type == "BACKUP" ? var.db_backup_id : null
  }

}

data "oci_psql_db_system_connection_detail" "main" {
  db_system_id = oci_psql_db_system.main.id
}
