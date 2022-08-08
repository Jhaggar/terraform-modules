account_id        = 906890597400
environment       = "dev"
component         = "tech-info"
aws_region        = "us-east-1"

#----------------------------------------------#

key_name          = "nothviginia-key"
vpc_id            = "vpc-037f20a3d6c9f7536"
subnet_prefix     = "default-subnet"
subnet_prefix_1   = "subnet-030313fef26f035be"
subnet_prefix_2   = "subnet-0f121ef2bf81617f9"
rds_name          = "dev-rds"
ami               = "ami-b73b63a0"
public_key_path   = "~/.ssh/id_rsa.pub"
instance_type     = "t2.micro"
highcpu           = 75
lowcpu            = 40
userdata          = "resources/script.tpl"
repository_owner  = "Jhaggar"
repository_name   = "covid19"
github_token      = "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"
bucket_name       = "sapp-codepipeline-s3-bucket-jhdgtfr"
# env_name        = "dev"
branch = "master"