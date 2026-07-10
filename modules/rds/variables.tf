variable "identifier" {
  description = "Base name used for all resources created by this module (DB instance/cluster identifier, subnet group, security group, parameter group)"
  type        = string
}

variable "use_aurora" {
  description = "true creates an Aurora cluster (aws_rds_cluster + aws_rds_cluster_instance); false creates a single aws_db_instance"
  type        = bool
  default     = false
}

variable "engine_family" {
  description = "Database engine family: \"postgres\" or \"mysql\". Translated internally to the matching RDS or Aurora engine name."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.engine_family)
    error_message = "engine_family must be either \"postgres\" or \"mysql\"."
  }
}

variable "engine_version" {
  description = "Database engine version (e.g. \"16.4\" for postgres, \"8.0.mysql_aurora.3.05.2\" for aurora-mysql). Must match engine_family/use_aurora."
  type        = string
}

variable "parameter_group_family" {
  description = "Parameter group family matching engine_family/engine_version, e.g. \"postgres16\", \"aurora-postgresql16\", \"mysql8.0\", \"aurora-mysql8.0\""
  type        = string
}

variable "instance_class" {
  description = "Instance class for the DB instance(s), e.g. \"db.t3.medium\""
  type        = string
  default     = "db.t3.medium"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment. Only applies when use_aurora = false (Aurora HA is controlled via aurora_instance_count instead)."
  type        = bool
  default     = false
}

variable "aurora_instance_count" {
  description = "Number of aws_rds_cluster_instance members to create when use_aurora = true (1 writer + N-1 readers)"
  type        = number
  default     = 1
}

variable "db_name" {
  description = "Name of the default database created on the instance/cluster"
  type        = string
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "master_password" {
  description = "Master password for the database. Leave null to have the module generate and manage a random password."
  type        = string
  default     = null
  sensitive   = true
}

variable "allocated_storage" {
  description = "Allocated storage in GB. Only applies when use_aurora = false."
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Storage type for a non-Aurora instance (e.g. \"gp3\"). Only applies when use_aurora = false."
  type        = string
  default     = "gp3"
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection on the instance/cluster"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip taking a final snapshot when the instance/cluster is destroyed"
  type        = bool
  default     = true
}

variable "publicly_accessible" {
  description = "Whether the database is publicly accessible. Only applies when use_aurora = false."
  type        = bool
  default     = false
}

variable "port" {
  description = "Database port. Leave null to use the engine's default (5432 for postgres, 3306 for mysql)."
  type        = number
  default     = null
}

variable "vpc_id" {
  description = "VPC ID the database and its security group are created in"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group (should be private subnets, at least 2 in different AZs)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the database on the DB port"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to the database on the DB port (e.g. an EKS node security group)"
  type        = list(string)
  default     = []
}

variable "db_parameters" {
  description = "Extra parameter group entries merged on top of the module's baseline (max_connections, log_statement, work_mem). Map of parameter name to value."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
