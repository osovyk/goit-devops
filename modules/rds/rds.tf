# Standalone RDS instance, created when var.use_aurora = false.

resource "aws_db_parameter_group" "this" {
  count = var.use_aurora ? 0 : 1

  name   = "${var.identifier}-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = merge(var.tags, { Name = "${var.identifier}-params" })
}

resource "aws_db_instance" "this" {
  count = var.use_aurora ? 0 : 1

  identifier     = var.identifier
  engine         = local.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.master_username
  password = local.master_password
  port     = local.port

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this[0].name

  multi_az                  = var.multi_az
  publicly_accessible       = var.publicly_accessible
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot"

  backup_retention_period = var.backup_retention_period

  tags = merge(var.tags, { Name = var.identifier })
}
