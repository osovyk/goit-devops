# Aurora cluster + writer/reader instances, created when var.use_aurora = true.

resource "aws_rds_cluster_parameter_group" "this" {
  count = var.use_aurora ? 1 : 0

  name   = "${var.identifier}-cluster-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = merge(var.tags, { Name = "${var.identifier}-cluster-params" })
}

resource "aws_rds_cluster" "this" {
  count = var.use_aurora ? 1 : 0

  cluster_identifier = var.identifier
  engine             = local.engine
  engine_version     = var.engine_version

  database_name   = var.db_name
  master_username = var.master_username
  master_password = local.master_password
  port            = local.port

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this[0].name

  storage_encrypted = true

  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot"

  tags = merge(var.tags, { Name = var.identifier })
}

resource "aws_rds_cluster_instance" "this" {
  count = var.use_aurora ? var.aurora_instance_count : 0

  identifier         = "${var.identifier}-${count.index}"
  cluster_identifier = aws_rds_cluster.this[0].id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this[0].engine
  engine_version     = aws_rds_cluster.this[0].engine_version

  publicly_accessible = var.publicly_accessible

  tags = merge(var.tags, { Name = "${var.identifier}-${count.index}" })
}
