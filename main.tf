data "aws_caller_identity" "current" {}

# Existing VPC we will be using to setup rds PostgreSQL instance
data "aws_vpc" "vpc" {
//  id = var.vpc_id
  tags =  {
    Name = var.vpc_name
  }
}

# Existing Subnet ids we will be using to setup rds PostgreSQL instance
data "aws_subnet_ids" "sapp_postgresql_private_subnets" {
  vpc_id = data.aws_vpc.vpc.id
  tags = {
    Name = var.subnet_prefix
  }
}

# Existing Security Group
//data "aws_security_group" "sapp_postgresql_sg" {
//  #id = var.db_security_group_name
//  id = [var.db_security_group_name,var.db_security_group_name1,var.db_security_group_name2,var.db_security_group_name3]
//}

//data "aws_security_group" "sapp_postgresql_sg" {
//  filter {
//    name = "group-id"
//    values = [var.db_security_group_name,var.db_security_group_name1,var.db_security_group_name2,var.db_security_group_name3]
//  }
//}

#### Database subnet group ####
resource "aws_db_subnet_group" "sapp_postgres_subnet_group" {
  name                            = var.db_subnet_group_name
  description                     = "Subnet group for PostgreSQL SAPP DB"
  subnet_ids                      = data.aws_subnet_ids.sapp_postgresql_private_subnets.ids
  tags = {
    Name = var.db_subnet_group_name
    component = var.component
  }
}

# Database parameter group: The set of parameters that requires to put for db instance while launching
resource "aws_db_parameter_group" "sapp_postgres_parameter_group" {
  name                          = var.db-parameter-group-name
  description                   = "Parameter group for PostgreSQL SAPP DB"
  family                        = var.db_family
  parameter {
    name = "log_connections"
    value = "1"
  }
  parameter {
    name = "log_disconnections"
    value = "1"
  }
  parameter {
    name = "log_statement"
    value = "none"
  }
  parameter {
    name = "log_duration"
    value = "0"
  }
  parameter {
    name = "log_min_duration_statement"
    value = "10"
  }
  parameter {
    name = "log_hostname"
    value = "0"
  }
  tags = {
    Name = var.db-parameter-group-name
    component = var.component
  }
}

//##### IAM resources ########
//data "aws_iam_policy_document" "enhanced_monitoring" {
//  statement {
//    effect = "Allow"
//    principals {
//      type        = "Service"
//      identifiers = ["monitoring.rds.amazonaws.com"]
//    }
//    actions = ["sts:AssumeRole"]
//  }
//}
//
//// need little touch-up
//resource "aws_iam_role" "enhanced_monitoring" {
//  name               = "rds${var.environment}EnhancedMonitoringRole"
//  assume_role_policy = data.aws_iam_policy_document.enhanced_monitoring.json
//}
//
//resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
//  role       = aws_iam_role.enhanced_monitoring.name
//  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
//}
//
//##################### KMS Policy ############################
data "template_file" "kms_policy" {
  template = file("resources/kms_policy.json.tpl")
  vars = {
    account_id = var.account_id
  }
}

resource "aws_kms_key" "sapp-authoring-KMS-Key" {
  description             = "A KMS key to encrypt the Aurora postgres database"
  policy                  = data.template_file.kms_policy.rendered
  tags = {
    Name = "SAPP-KMS-Key"
    component = var.component
  }
}

resource "aws_kms_alias" "sapp-authoring-KMS-Key-Alias" {
  name          = "alias/${var.sapp_kms_alias}"
  target_key_id = aws_kms_key.sapp-authoring-KMS-Key.key_id
}

#### Secret Manager
resource "random_password" "rds_password" {
  length = 16
  special = false
}

resource "aws_secretsmanager_secret" "sapprdssecret" {
  name = var.secret_key
  tags = {
    Name = "SAPP-Secret-key"
    component = var.component
  }
}

resource "aws_secretsmanager_secret_version" "secretValue" {
  secret_id     = aws_secretsmanager_secret.sapprdssecret.id
  secret_string = random_password.rds_password.result
}

//resource "aws_sns_topic" "sapp-sns-topic" {
//  name = var.topic
//  display_name = var.display_name
//  provisioner "local-exec" {
//    command = "sh resources/sns_subscription.sh"
//    environment = {
//      sns_arn = self.arn
//      sns_emails = var.email_address
//    }
//  }
//  tags = {
//    Name = var.topic
//    component = var.component
//  }
//}

########### SNS topic ###############
resource "aws_sns_topic" "sapp-sns-topic" {
  name = var.topic
  tags = {
    Name = var.topic
    component = var.component
  }
}

resource "aws_sns_topic_subscription" "email-target" {
  topic_arn = aws_sns_topic.sapp-sns-topic.arn
  protocol  = "email"
  endpoint  = var.email_address
}

# RDS resources
resource "aws_db_instance" "postgresql" {
  allocated_storage               = var.allocated_storage
  publicly_accessible             = var.publicly_accessible
  identifier                      = var.database_identifier
  db_name                         = var.db_name
  engine                          = var.engine
  engine_version                  = var.engine_version
  instance_class                  = var.instance_class
  iops                            = var.iops
  username                        = var.database_username
  password                        = aws_secretsmanager_secret_version.secretValue.secret_string
  port                            = var.database_port
  #vpc_security_group_ids          = data.aws_security_group.sapp_postgresql_sg.id
  vpc_security_group_ids          = [var.db_security_group_name,var.db_security_group_name1,var.db_security_group_name2,var.db_security_group_name3]
  db_subnet_group_name            = aws_db_subnet_group.sapp_postgres_subnet_group.name
  parameter_group_name            = aws_db_parameter_group.sapp_postgres_parameter_group.name
  deletion_protection             = var.deletion_protection
  apply_immediately               = var.apply_immediately
  kms_key_id                      = aws_kms_key.sapp-authoring-KMS-Key.arn
  #kms_key_id                      = var.kms_key
  storage_encrypted               = var.storage_encrypted
  final_snapshot_identifier       = var.final_snapshot_identifier
  skip_final_snapshot             = var.skip_final_snapshot
  backup_retention_period         = var.backup_retention_period
  backup_window                   = var.backup_window
  maintenance_window              = var.maintenance_window
  copy_tags_to_snapshot           = var.copy_tags_to_snapshot
  auto_minor_version_upgrade      = var.auto_minor_version_upgrade
  multi_az                        = var.multi_availability_zone
  enabled_cloudwatch_logs_exports = var.cloudwatch_logs_exports
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_role_arn
  //monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring.arn : ""

  #monitoring_role_arn             = var.monitoring_role_arn
  #enable_http_endpoint            = true
  #snapshot_identifier             = var.snapshot_identifier
  #storage_type                    = var.storage_type
  tags = {
    Name = var.db_name
    component = var.component
  }
}

# CloudWatch resources
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  //alarm_name          = "alarm-${var.environment}-DatabaseServerCPUUtilization-${var.database_identifier}"
  alarm_name          = "rds-${aws_db_instance.postgresql.id}-sapp-DatabaseServerCPUUtilization"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  unit                = "Percent"
  period              = "300"
  evaluation_periods  = "1"
  statistic           = "Average"
  #threshold           = var.alarm_cpu_threshold
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_description   = "Database server CPU utilization"
  #alarm_actions             = var.alarm_actions
  alarm_actions             = [aws_sns_topic.sapp-sns-topic.arn]
  #insufficient_data_actions = var.insufficient_data_actions
  insufficient_data_actions = [aws_sns_topic.sapp-sns-topic.arn]
  #ok_actions                = var.ok_actions
//  dimensions = {
//    DBInstanceIdentifier = aws_db_instance.postgresql.identifier
//  }
}

resource "aws_cloudwatch_metric_alarm" "database_memory_free" {
  #alarm_name                = "alarm-${var.environment}-DatabaseServerFreeableMemory-${var.database_identifier}"
  alarm_name                = "rds-${aws_db_instance.postgresql.id}-sapp-DatabaseServerFreeableMemory"
  alarm_description         = "Database server freeable memory"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "3"
  metric_name               = "FreeableMemory"
  namespace                 = "AWS/RDS"
  unit                      = "Bytes"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = var.alarm_free_memory_threshold
  alarm_actions             = [aws_sns_topic.sapp-sns-topic.arn]
  insufficient_data_actions = [aws_sns_topic.sapp-sns-topic.arn]
  #ok_actions                = var.ok_actions
//  dimensions = {
//    DBInstanceIdentifier = aws_db_instance.postgresql
//  }
}

resource "aws_cloudwatch_metric_alarm" "database_disk_queue" {
  #alarm_name                 = "alarm-${var.environment}-DatabaseServerDiskQueueDepth-${var.database_identifier}"
  alarm_name                  = "rds-${aws_db_instance.postgresql.id}-sapp-DatabaseServerDiskQueueDepth"
  alarm_description           = "Database server disk queue depth"
  namespace                   = "AWS/RDS"
  comparison_operator         = "GreaterThanThreshold"
  evaluation_periods          = "1"
  metric_name                 = "DiskQueueDepth"
  period                      = "60"
  statistic                   = "Average"
  threshold                   = var.alarm_disk_queue_threshold
  alarm_actions               = [aws_sns_topic.sapp-sns-topic.arn]
  insufficient_data_actions   = [aws_sns_topic.sapp-sns-topic.arn]
  #ok_actions                = var.ok_actions
//  dimensions = {
//    DBInstanceIdentifier = aws_db_instance.postgresql
//  }
}

resource "aws_cloudwatch_metric_alarm" "database_disk_free" {
  #alarm_name               = "alarm-${var.environment}-DatabaseServerFreeStorageSpace-${var.database_identifier}"
  alarm_name                = "rds-${aws_db_instance.postgresql.id}-sapp-DatabaseServerFreeStorageSpace"
  alarm_description         = "Database server free storage space"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "FreeStorageSpace"
  namespace                 = "AWS/RDS"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = var.alarm_free_disk_threshold
  alarm_actions             = [aws_sns_topic.sapp-sns-topic.arn]
  insufficient_data_actions = [aws_sns_topic.sapp-sns-topic.arn]
  #ok_actions                = var.ok_actions
//  dimensions = {
//    DBInstanceIdentifier = aws_db_instance.postgresql
//  }
}

resource "aws_cloudwatch_metric_alarm" "database_cpu_credits" {
  // This results in 1 if instance_type starts with "db.t", 0 otherwise.
  //count = substr(var.instance_type, 0, 3) == "db.t" ? 1 : 0
  #alarm_name               = "alarm-${var.environment}-DatabaseCPUCreditBalance-${var.database_identifier}"
  alarm_name                = "rds-${aws_db_instance.postgresql.id}-sapp-DatabaseCPUCreditBalance"
  alarm_description         = "Database CPU credit balance"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUCreditBalance"
  namespace                 = "AWS/RDS"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = var.alarm_cpu_credit_balance_threshold
  alarm_actions             = [aws_sns_topic.sapp-sns-topic.arn]
  insufficient_data_actions = [aws_sns_topic.sapp-sns-topic.arn]
  #ok_actions                = var.ok_actions
//  dimensions = {
//    DBInstanceIdentifier = aws_db_instance.postgresql
//  }
}


####################### LogGroup ###############################
## Keep LogGroup name in patteren /aws/rds/example-cluster/<cluster_name>/<item>,
## even if we specify different log group it will create default LogGroup additionally in above pattern and,
## logs will be redirected to default LogGroup
resource "aws_cloudwatch_log_group" "sapp-postgresql-LogGroup" {
  name = var.log_group_name
  retention_in_days = 7
  tags = {
    Name = "diagnostics-sapp-postgresql-LogGroup"
    component = var.component
  }
}

# Audit filters and alarms
resource "aws_cloudwatch_log_metric_filter" "sapp_auth_audit_filter" {
  name           = var.audit_auth_filter_name
  pattern        = "authentication failed for user"
  log_group_name = aws_cloudwatch_log_group.sapp-postgresql-LogGroup.name
  metric_transformation {
    name      = "FailedAuthCount"
    namespace = var.audit_auth_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "sa_sapp_auth_audit_alarm" {
  //alarm_name                  = "rds-${aws_rds_cluster_instance.example-postgresql-instance.*.id[count.index]}-AuthAuditAlarm"
  alarm_name                    = "rds-${aws_db_instance.postgresql.id}-sapp-AuthAuditAlarm"
  comparison_operator           = "GreaterThanOrEqualToThreshold"
  evaluation_periods            = 12
  metric_name                   = "FailedAuthCount"
  #unit                         = "Count"
  namespace                     = var.audit_auth_namespace
  period                        = 300
  statistic                     = "Sum"
  threshold                     = 5
  treat_missing_data            = "notBreaching"
  datapoints_to_alarm           = 1
  alarm_description             = "RDS swap usage for RDS aurora cluster alarm${var.environment}DatabaseCPUCreditBalance-${var.database_identifier}"
  alarm_actions                 = [aws_sns_topic.sapp-sns-topic.arn]
  insufficient_data_actions     = [aws_sns_topic.sapp-sns-topic.arn]
  depends_on                    = [aws_cloudwatch_log_metric_filter.sapp_auth_audit_filter]
  tags = {
    Name = "sapp_auth_audit_alarm"
    component = var.component
  }

}

# DB event Subscription
resource "aws_db_event_subscription" "sa_sapp_DBEventSubscription" {
  enabled          = true
  event_categories = ["configuration change", "failure","deletion","availability","backup","failover","maintenance","notification","read replica","recovery","low storage"]
  name             = var.db_event_subscription_name
  sns_topic        = aws_sns_topic.sapp-sns-topic.arn
  source_ids       = aws_db_instance.postgresql.*.id
  source_type      = "db-instance"
  tags = {
    Name = var.db_event_subscription_name
    component = var.component
  }
  depends_on = [aws_sns_topic.sapp-sns-topic]
}



