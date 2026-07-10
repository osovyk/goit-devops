# rds

Універсальний Terraform-модуль для бази даних на AWS. Залежно від прапора
`use_aurora` створює або звичайну `aws_db_instance` (RDS), або Aurora-кластер
(`aws_rds_cluster` + `aws_rds_cluster_instance`). В обох випадках модуль сам
створює DB Subnet Group, Security Group і Parameter Group під обраний тип БД.

## Що створюється

| Ресурс | use_aurora = false | use_aurora = true |
| --- | --- | --- |
| `aws_db_subnet_group` | ✅ | ✅ |
| `aws_security_group` | ✅ | ✅ |
| `aws_db_instance` | ✅ | — |
| `aws_db_parameter_group` | ✅ | — |
| `aws_rds_cluster` | — | ✅ |
| `aws_rds_cluster_instance` (×`aurora_instance_count`) | — | ✅ |
| `aws_rds_cluster_parameter_group` | — | ✅ |
| `random_password` | тільки якщо `master_password` не задано | тільки якщо `master_password` не задано |

## Приклад використання

### Звичайна RDS (PostgreSQL)

```hcl
module "rds" {
  source = "./modules/rds"

  identifier      = "myapp-db"
  use_aurora      = false
  engine_family   = "postgres"
  engine_version  = "16.4"
  parameter_group_family = "postgres16"
  instance_class  = "db.t3.medium"
  multi_az        = true

  db_name         = "myapp"
  master_username = "myapp_admin"
  # master_password не задано -> модуль згенерує випадковий і поверне у виводі

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  allowed_security_group_ids = [module.eks.eks_node_security_group_id]

  tags = {
    Project = "myapp"
  }
}
```

### Aurora-кластер (PostgreSQL-сумісний)

```hcl
module "rds_aurora" {
  source = "./modules/rds"

  identifier      = "myapp-aurora"
  use_aurora      = true
  engine_family   = "postgres"
  engine_version  = "16.4"
  parameter_group_family = "aurora-postgresql16"
  instance_class  = "db.r6g.large"
  aurora_instance_count = 2 # 1 writer + 1 reader

  db_name         = "myapp"
  master_username = "myapp_admin"
  master_password = var.db_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}
```

### MySQL замість PostgreSQL

Досить змінити `engine_family` і відповідні версійні поля — уся інша логіка
модуля (subnet group, SG, parameter group) не залежить від СУБД:

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

## Як змінити тип БД / engine / клас інстансу

- **RDS ⇄ Aurora** — прапор `use_aurora` (`true`/`false`). Це форс-заміна
  ресурсів (RDS instance видаляється, створюється Aurora cluster, або
  навпаки) — не гаряче перемикання на існуючих даних.
- **PostgreSQL ⇄ MySQL** — `engine_family` (`"postgres"` / `"mysql"`).
  Модуль сам підставляє правильний `engine` для `aws_db_instance`
  (`postgres`/`mysql`) чи `aws_rds_cluster` (`aurora-postgresql`/`aurora-mysql`).
- **Версія двигуна** — `engine_version`. Значення відрізняється між RDS і
  Aurora навіть для того самого `engine_family` — перевіряйте доступні версії
  через `aws rds describe-db-engine-versions --engine <engine>`.
- **Клас інстансу** — `instance_class` (напр. `db.t3.medium`, `db.r6g.large`).
  Для Aurora застосовується до кожного `aws_rds_cluster_instance`.
- **Кількість Aurora-інстансів** — `aurora_instance_count` (1 writer +
  N-1 readers). Не застосовується при `use_aurora = false` — там
  використовуйте `multi_az = true` замість декількох інстансів.
- **Параметри БД** — базові (`max_connections`, `log_statement`/`general_log`,
  `work_mem`/`sort_buffer_size`) виставляються автоматично залежно від
  `engine_family`; додаткові/перевизначені параметри — через мапу
  `db_parameters`.

## Змінні

| Змінна | Опис | Тип | За замовчуванням |
| --- | --- | --- | --- |
| `identifier` | Базове ім'я всіх ресурсів модуля | `string` | — (обов'язкова) |
| `use_aurora` | `true` → Aurora cluster, `false` → звичайна RDS instance | `bool` | `false` |
| `engine_family` | `"postgres"` або `"mysql"` | `string` | `"postgres"` |
| `engine_version` | Версія движка (має відповідати `engine_family`/`use_aurora`) | `string` | — (обов'язкова) |
| `parameter_group_family` | Family для parameter group, напр. `"postgres16"`, `"aurora-postgresql16"` | `string` | — (обов'язкова) |
| `instance_class` | Клас інстансу | `string` | `"db.t3.medium"` |
| `multi_az` | Multi-AZ для звичайної RDS (ігнорується для Aurora) | `bool` | `false` |
| `aurora_instance_count` | Кількість інстансів в Aurora-кластері | `number` | `1` |
| `db_name` | Ім'я дефолтної бази даних | `string` | — (обов'язкова) |
| `master_username` | Ім'я адміністратора БД | `string` | `"admin"` |
| `master_password` | Пароль адміністратора. `null` → модуль згенерує та поверне у `master_password` output | `string` | `null` |
| `allocated_storage` | Розмір диска в ГБ (тільки для звичайної RDS) | `number` | `20` |
| `storage_type` | Тип диска (тільки для звичайної RDS) | `string` | `"gp3"` |
| `backup_retention_period` | Днів зберігання автобекапів | `number` | `7` |
| `deletion_protection` | Захист від випадкового видалення | `bool` | `false` |
| `skip_final_snapshot` | Пропустити фінальний снапшот при видаленні | `bool` | `true` |
| `publicly_accessible` | Публічний доступ до БД | `bool` | `false` |
| `port` | Порт БД. `null` → дефолтний порт движка (5432/3306) | `number` | `null` |
| `vpc_id` | VPC для security group | `string` | — (обов'язкова) |
| `subnet_ids` | Підмережі для DB subnet group (private, ≥2 AZ) | `list(string)` | — (обов'язкова) |
| `allowed_cidr_blocks` | CIDR-блоки з доступом до БД | `list(string)` | `[]` |
| `allowed_security_group_ids` | Security groups з доступом до БД | `list(string)` | `[]` |
| `db_parameters` | Додаткові/перевизначені параметри parameter group | `map(string)` | `{}` |
| `tags` | Теги для всіх ресурсів модуля | `map(string)` | `{}` |

## Виводи

| Вивід | Опис |
| --- | --- |
| `endpoint` | Connection endpoint (writer endpoint для Aurora, endpoint для звичайної RDS) |
| `reader_endpoint` | Aurora reader endpoint (`null` для звичайної RDS) |
| `port` | Порт БД |
| `db_name` | Ім'я дефолтної бази даних |
| `master_username` | Ім'я адміністратора |
| `master_password` | Пароль адміністратора (sensitive) |
| `security_group_id` | ID security group бази даних |
| `subnet_group_name` | Ім'я DB subnet group |
| `id` | Ідентифікатор cluster/instance |
| `arn` | ARN cluster/instance |
