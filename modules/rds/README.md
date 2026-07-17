# rds

Universal Terraform module for an AWS database. Depending on the `use_aurora` flag it creates
either a standalone `aws_db_instance` (RDS) or an Aurora cluster (`aws_rds_cluster` +
`aws_rds_cluster_instance`). In both cases the module creates its own DB Subnet Group,
Security Group, and a Parameter Group matching the selected database type.

## What gets created

| Resource | use_aurora = false | use_aurora = true |
| --- | --- | --- |
| `aws_db_subnet_group` | ✅ | ✅ |
| `aws_security_group` | ✅ | ✅ |
| `aws_db_instance` | ✅ | — |
| `aws_db_parameter_group` | ✅ | — |
| `aws_rds_cluster` | — | ✅ |
| `aws_rds_cluster_instance` (×`aurora_instance_count`) | — | ✅ |
| `aws_rds_cluster_parameter_group` | — | ✅ |
| `random_password` | only if `master_password` is not set | only if `master_password` is not set |

> The standalone RDS path (`use_aurora = false`, PostgreSQL 17.6, `db.t3.micro`) has been
> deployed and verified end-to-end: the instance reached the `available` state, the parameter
> group applied all three baseline parameters (`max_connections`, `log_statement`, `work_mem`),
> and the security group correctly restricted access to port 5432 to the given CIDR. The Aurora
> path has been verified via `terraform plan` (correct resource set with no leftover RDS
> resources) but not deployed end-to-end.

## Usage example

### Standalone RDS (PostgreSQL)

```hcl
module "rds" {
  source = "./modules/rds"

  identifier      = "myapp-db"
  use_aurora      = false
  engine_family   = "postgres"
  engine_version  = "17.6"
  parameter_group_family = "postgres17"
  instance_class  = "db.t3.medium"
  multi_az        = true

  db_name         = "myapp"
  master_username = "myapp_admin"
  # master_password not set -> the module generates a random one and returns it as an output

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  allowed_security_group_ids = [module.eks.eks_node_security_group_id]

  tags = {
    Project = "myapp"
  }
}
```

### Aurora cluster (PostgreSQL-compatible)

```hcl
module "rds_aurora" {
  source = "./modules/rds"

  identifier      = "myapp-aurora"
  use_aurora      = true
  engine_family   = "postgres"
  engine_version  = "17.6"
  parameter_group_family = "aurora-postgresql17"
  instance_class  = "db.r6g.large"
  aurora_instance_count = 2 # 1 writer + 1 reader

  db_name         = "myapp"
  master_username = "myapp_admin"
  master_password = var.db_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}
```

### MySQL instead of PostgreSQL

Change `engine_family` and the matching version fields — the rest of the module's logic
(subnet group, SG, parameter group) does not depend on the database engine:

```hcl
module "rds_mysql" {
  source = "./modules/rds"

  identifier      = "myapp-mysql"
  use_aurora      = false
  engine_family   = "mysql"
  engine_version  = "8.0.39"
  parameter_group_family = "mysql8.0"

  db_name         = "myapp"
  master_username = "myapp_admin"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}
```

## How to change the DB type / engine / instance class

- **RDS ⇄ Aurora** — the `use_aurora` flag (`true`/`false`). This is a forced resource
  replacement (the RDS instance is destroyed and an Aurora cluster is created, or vice
  versa) — not a hot switch on existing data.
- **PostgreSQL ⇄ MySQL** — `engine_family` (`"postgres"` / `"mysql"`). The module derives
  the correct `engine` for `aws_db_instance` (`postgres`/`mysql`) or `aws_rds_cluster`
  (`aurora-postgresql`/`aurora-mysql`) by itself.
- **Engine version** — `engine_version`. Values differ between RDS and Aurora even for the
  same `engine_family` — check the available versions with
  `aws rds describe-db-engine-versions --engine <engine>`.
- **Instance class** — `instance_class` (e.g. `db.t3.medium`, `db.r6g.large`). For Aurora
  it is applied to every `aws_rds_cluster_instance`.
- **Number of Aurora instances** — `aurora_instance_count` (1 writer + N-1 readers). Not
  applicable when `use_aurora = false` — use `multi_az = true` there instead of multiple
  instances.
- **Database parameters** — the baseline ones (`max_connections`, `log_statement`/`general_log`,
  `work_mem`/`sort_buffer_size`) are set automatically based on `engine_family`; extra or
  overridden parameters go through the `db_parameters` map.

## Variables

| Variable | Description | Type | Default |
| --- | --- | --- | --- |
| `identifier` | Base name for all resources created by the module | `string` | — (required) |
| `use_aurora` | `true` → Aurora cluster, `false` → standalone RDS instance | `bool` | `false` |
| `engine_family` | `"postgres"` or `"mysql"` | `string` | `"postgres"` |
| `engine_version` | Engine version (must match `engine_family`/`use_aurora`) | `string` | — (required) |
| `parameter_group_family` | Parameter group family, e.g. `"postgres16"`, `"aurora-postgresql16"` | `string` | — (required) |
| `instance_class` | Instance class | `string` | `"db.t3.medium"` |
| `multi_az` | Multi-AZ for standalone RDS (ignored for Aurora) | `bool` | `false` |
| `aurora_instance_count` | Number of instances in the Aurora cluster | `number` | `1` |
| `db_name` | Name of the default database | `string` | — (required) |
| `master_username` | Database admin username. **Do not use `"admin"`** — it is a reserved word for PostgreSQL on RDS, `CreateDBInstance` fails with `InvalidParameterValue` | `string` | `"dbadmin"` |
| `master_password` | Admin password. `null` → the module generates one and returns it as the `master_password` output | `string` | `null` |
| `allocated_storage` | Storage size in GB (standalone RDS only) | `number` | `20` |
| `storage_type` | Storage type (standalone RDS only) | `string` | `"gp3"` |
| `backup_retention_period` | Days to retain automated backups | `number` | `7` |
| `deletion_protection` | Protection against accidental deletion | `bool` | `false` |
| `skip_final_snapshot` | Skip the final snapshot on deletion | `bool` | `true` |
| `publicly_accessible` | Public access to the database | `bool` | `false` |
| `port` | Database port. `null` → the engine's default port (5432/3306) | `number` | `null` |
| `vpc_id` | VPC for the security group | `string` | — (required) |
| `subnet_ids` | Subnets for the DB subnet group (private, ≥2 AZs) | `list(string)` | — (required) |
| `allowed_cidr_blocks` | CIDR blocks allowed to access the database | `list(string)` | `[]` |
| `allowed_security_group_ids` | Security groups allowed to access the database | `list(string)` | `[]` |
| `db_parameters` | Extra / overridden parameter group entries | `map(string)` | `{}` |
| `tags` | Tags for all resources created by the module | `map(string)` | `{}` |

## Outputs

| Output | Description |
| --- | --- |
| `endpoint` | Connection endpoint (writer endpoint for Aurora, instance endpoint for standalone RDS) |
| `reader_endpoint` | Aurora reader endpoint (`null` for standalone RDS) |
| `port` | Database port |
| `db_name` | Name of the default database |
| `master_username` | Admin username |
| `master_password` | Admin password (sensitive) |
| `security_group_id` | ID of the database security group |
| `subnet_group_name` | Name of the DB subnet group |
| `id` | Cluster/instance identifier |
| `arn` | Cluster/instance ARN |
