resource "oci_vault_secret" "main" {
  compartment_id = var.compartment_id
  vault_id       = var.kms_vault_id
  key_id         = var.kms_key_id
  secret_name    = "${var.project}-${var.environment}-${var.name}-db-password"
  freeform_tags  = var.tags

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.main.result)
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

resource "oci_core_network_security_group_security_rule" "pgsql_ingress" {
  for_each                  = toset(var.allowed_cidrs)
  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }
}

resource "oci_core_network_security_group_security_rule" "pgsql_egress" {
  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 1024
      max = 65535
    }
  }
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
    availability_domain   = var.availability_domain
    is_regionally_durable = var.availability_domain == null ? true : false
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

  lifecycle {
    ignore_changes = [instance_count] # let null_resource handle scaling
  }
}

data "oci_psql_db_system_connection_detail" "main" {
  db_system_id = oci_psql_db_system.main.id
}

resource "null_resource" "psql_scale" {
  # Triggers re-run whenever instance_count changes
  triggers = {
    instance_count = var.instance_count
    db_system_id   = oci_psql_db_system.main.id
  }

  provisioner "local-exec" {
    command = <<EOT
      bash ${path.module}/psql-scale.sh \
        ${oci_psql_db_system.main.id} \
        ${var.instance_count}
    EOT
  }

  depends_on = [oci_psql_db_system.main]
}
