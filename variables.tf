variable "project" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "The environment (e.g., dev, prod)."
  type        = string
}

variable "name" {
  description = "The name of the resource."
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment."
  type        = string
}

variable "vcn_id" {
  description = "The OCID of the VCN where the database system will be created."
  type        = string
}

variable "allowed_cidrs" {
  description = "List of CIDR blocks permitted to reach the PostgreSQL cluster on port 5432. Pass your application-tier subnet CIDRs."
  type        = list(string)
}

variable "kms_vault_id" {
  description = "The OCID of the KMS vault to use for storing the database password."
  type        = string
}

variable "kms_key_id" {
  description = "The OCID of the KMS key to use for encrypting the database password."
  type        = string
}

variable "db_version" {
  description = "The version of the database."
  type        = string
}

variable "instance_count" {
  description = "The number of database instances to create."
  type        = number
}

variable "db_system_shape" {
  description = "The shape of the database system."
  type        = string
}

variable "db_username" {
  description = "The username for the database."
  type        = string
}

variable "subnet_id" {
  description = "The OCID of the subnet where the database will be created."
  type        = string
}

variable "is_reader_endpoint_enabled" {
  description = "Whether to enable the reader endpoint for the database system."
  type        = bool
  default     = false
}

variable "storage_iops" {
  description = "The number of IOPS to provision for the database system's storage."
  type        = number
}

variable "instance_memory_size_in_gbs" {
  description = "The amount of memory (in GBs) to allocate for each database instance."
  type        = number
}

variable "instance_ocpu_count" {
  description = "The number of OCPUs to allocate for each database instance."
  type        = number
}

variable "backup_start_time" {
  description = "The start time for the backup schedule."
  type        = string
  default     = "02:00"
}

variable "backup_retention_days" {
  description = "The number of days to retain backups."
  type        = number
  default     = 14
}

variable "db_source_type" {
  description = "The source type for the database system."
  type        = string
  default     = "NONE"
}

variable "db_backup_id" {
  description = "The OCID of the backup to use as the source for the database system."
  type        = string
  default     = null
}

variable "tags" {
  description = "Free-form tags to apply to the resource."
  type        = map(string)
  default     = null
}
