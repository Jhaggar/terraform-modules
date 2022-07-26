#---------------------------------------------------------------------------------------------------------
# This is called the variable file from where we pass the variable values to the main.tf terraform file.
# Terraform pickups this file as by default for variables.
#---------------------------------------------------------------------------------------------------------
component = "tech-info"
region = "us-east-1"
database_identifier = "postgres"
db_name = "postgressapp"
database_username = "johndereesapp1"
engine= "postgres"
engine_version = "14"
db_family = "postgres14"
database_port = 5432
publicly_accessible = false
auto_minor_version_upgrade = false
backup_window = "04:00-04:30"
maintenance_window = "sun:04:30-sun:05:30"
backup_retention_period = 1
deletion_protection = false
apply_immediately = true
storage_encrypted = true
skip_final_snapshot = false
iops = 0
copy_tags_to_snapshot = false
cloudwatch_logs_exports = ["postgresql"]
email_address = "riteshjhaggar1988@gmail.com"
protocol = "email"
stack_name = "sapp-sns-stack"


###########################################################
################## variable parameter #####################
###########################################################
//backend_S3_bucket_name = ""
instance_count = 1

account_id = "906890597400"

environment = "devl"

### VPC ####
//vpc_name = "default"                   // personl
vpc_id = "vpc-037f20a3d6c9f7536"        // Johnderee

#### SUBNET ID ###
subnet_prefix = "default-subnet"
//subnet_prefix = "vpn-devl-Private"
subnet_id_1 = "subnet-030f687267646673e"
subnet_id_2 = "subnet-055a700a6321eee09"

### Security Group #####
db_security_group_name = "sg-035b67f6a4e3b8edc"
db_security_group_name1 = "sg-049744ce10d2a313f"
db_security_group_name2 = "sg-0626c973e921c9b62"
db_security_group_name3 = "sg-03d39443dabd8a447"
//db_security_group_name = "sg-"

#### SUBNET GROUP #### ? DO we have to use or create new
db_subnet_group_name = "johnderee-subnet-group"
//db_subnet_group_name = ""

#### Parameter GROUP #### ? DO we have to use or create new
db-parameter-group-name = "johnderee-parameter-group"
//db-parameter-group-name = ""

### Requirement about Storage ??? #####
allocated_storage = 20

### Suggestion on types ??? #####
instance_class = "db.t3.micro"

##### Secret Key name #####
secret_key = "CHANNEL/johndereee-jdhjdaasdA"

#### KMS KEY ####
#sapp_kms_alias = demojohnderee2
#kms_key = "johnderee/kmstest1512"
kms_key = "arn:aws:kms:us-east-1:906890597400:key/656650a1-056f-4955-bcdb-6027e268c95e"

final_snapshot_identifier = "johnderee-final-snapshot"

multi_availability_zone = false

monitoring_interval = 30

monitoring_role_arn = "arn:aws:iam::906890597400:role/rdsdevlEnhancedMonitoringRole"

# 524MB
alarm_free_memory_threshold = 524288000

alarm_disk_queue_threshold = 60

#10 GB
alarm_free_disk_threshold = 10000000000

alarm_cpu_credit_balance_threshold = 60

topic = "johnderee2"

display_name = "johnderee-testing2"

log_group_name = "/aws/rds/sapp-devl-cloudwatch-log"

audit_auth_filter_name = "johnderee-auth-filter"

audit_auth_namespace = "johnderee-auth-filter/auth"

db_event_subscription_name = "db-event-subscription-name-johnderee"
