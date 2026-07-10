terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

locals {
  engine = var.use_aurora ? (
    var.engine_family == "postgres" ? "aurora-postgresql" : "aurora-mysql"
  ) : var.engine_family

  port = coalesce(var.port, var.engine_family == "postgres" ? 5432 : 3306)

  master_password = coalesce(var.master_password, try(random_password.this[0].result, null))

  # Baseline parameter group entries required by the assignment (max_connections,
  # log_statement, work_mem). log_statement/work_mem are PostgreSQL-only, so MySQL
  # gets the closest equivalents (general_log, sort_buffer_size) instead of an
  # apply-time error from setting a nonexistent parameter.
  baseline_parameters = var.engine_family == "postgres" ? {
    max_connections = "100"
    log_statement   = "ddl"
    work_mem        = "4096"
    } : {
    max_connections  = "100"
    general_log      = "1"
    sort_buffer_size = "262144"
  }

  parameters = merge(local.baseline_parameters, var.db_parameters)
}

resource "random_password" "this" {
  count = var.master_password == null ? 1 : 0

  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.identifier}-subnet-group" })
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Security group for ${var.identifier} database"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "Database access from allowed CIDR blocks"
      from_port   = local.port
      to_port     = local.port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids
    content {
      description     = "Database access from ${ingress.value}"
      from_port       = local.port
      to_port         = local.port
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.identifier}-sg" })
}
