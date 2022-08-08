
################################## VPC #######################################

data "aws_availability_zones" "available" {}

data "aws_vpc" "vpc" {
    id = var.vpc_id
}

################################## SUBNET  #######################################
data "aws_subnet_ids" "sapp_postgresql_private_subnets" {
  vpc_id = data.aws_vpc.vpc.id
  tags = {
    Name = var.subnet_prefix
  }
}

################################## VPC #######################################

################################## EC2 #######################################

//provider "aws" {
// region = var.aws_region
//}

##################### Instance Security Group ###########################

resource "aws_security_group" "instance_sg" {
  name        = "sapp_instance_sg-${var.environment}"
  description = "Web Server Security Group"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "sapp_instance_sg-${var.environment}"
    component = var.component
  }
}

#################### Application Load Balancer Security Group ##################

resource "aws_security_group" "alb_sg" {
  name = "sapp_alb_sg-${var.environment}"
  description = "Application Load Balancer Security Group"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "sapp_alb_sg-${var.environment}"
    component = var.component
  }
}

####################### Launch Configuration ###################################
resource "aws_launch_configuration" "sapp_web" {
  name                  = "sapp_launch_config_${var.environment}"
  image_id              = var.ami
  instance_type         = var.instance_type
  key_name              = var.key_name
  security_groups       = [aws_security_group.instance_sg.id]
  iam_instance_profile  = aws_iam_instance_profile.webserver_profile.name
  user_data             = templatefile(var.userdata, {
    environment = var.environment
    rds_name = var.rds_name
  })
  lifecycle {
    create_before_destroy = true
  }
}

####################### Auto Scaling Group #######################
resource "aws_autoscaling_group" "sapp_web" {
  name                      = "sapp_auto_scaling_${var.environment}"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  default_cooldown          = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = aws_launch_configuration.sapp_web.name
  vpc_zone_identifier       = [var.subnet_prefix_1,var.subnet_prefix_2]
  depends_on                = [aws_launch_configuration.sapp_web]
  tag {
    key                 = "Name"
    value               = "sapp_auto_scaling_${var.environment}"
    propagate_at_launch = true
  }
  tag {
    key                 = "component"
    value               = var.component
    propagate_at_launch = true
  }
  lifecycle {
    ignore_changes = [target_group_arns]
  }

}

#######################  Auto Scaling Policies #######################
resource "aws_autoscaling_policy" "scaleup" {
  name                   = "sapp_add_server_${var.environment}"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.sapp_web.name
  depends_on             = [aws_autoscaling_group.sapp_web]
}

resource "aws_autoscaling_policy" "scaledown" {
  name                   = "sapp_remove_server_${var.environment}"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.sapp_web.name
  depends_on             = [aws_autoscaling_group.sapp_web]
}

####################### Application Load Balancer ####################################
resource "aws_lb" "sapp_web" {
  name                             = join("-", [var.environment, "alb"])
  internal                         = false
  load_balancer_type               = "application"
  security_groups                  = [aws_security_group.alb_sg.id]
  subnets                          = [var.subnet_prefix_1,var.subnet_prefix_2]
  enable_cross_zone_load_balancing = true
  tags = {
    Name      = "sapp_alb_${var.environment}"
    component = var.component
  }
}

######################### ALB Target Group ####################################
resource "aws_lb_target_group" "sapp_web" {
  depends_on = [aws_lb.sapp_web]
  name     = join("-", [var.environment, "target-group"])
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

######################### ALB Target Group Attachment #########################
resource "aws_autoscaling_attachment" "asg_attachment_web" {
  depends_on = [aws_lb_target_group.sapp_web]
  autoscaling_group_name = aws_autoscaling_group.sapp_web.id
  alb_target_group_arn   = aws_lb_target_group.sapp_web.arn
}

######################### ALB Listener ########################################
resource "aws_lb_listener" "sapp_web_front_end" {
  depends_on = [aws_lb_target_group.sapp_web]
  load_balancer_arn = aws_lb.sapp_web.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sapp_web.arn
  }
}

######################### Cloud Watch Alarm High ########################################

resource "aws_cloudwatch_metric_alarm" "high" {
  alarm_name          = "sapp_cpu_high_utilization_${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = var.highcpu
  alarm_description   = "Scale down web servers when CPU utilization is more than threshold"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.sapp_web.name
  }
  alarm_actions = [aws_autoscaling_policy.scaleup.arn]
  depends_on    = [aws_autoscaling_group.sapp_web]
  tags = {
    Name      = "sapp_cpu_high_utilization_${var.environment}"
    component = var.component
  }
}

######################### Cloud Watch Alarm Low ########################################
resource "aws_cloudwatch_metric_alarm" "low" {
  alarm_name          = "sapp_cpu_low_utilization_${var.environment}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = var.lowcpu
  alarm_description   = "Scale down web servers when CPU utilization is less than threshold"
  dimensions          = {
    AutoScalingGroupName = aws_autoscaling_group.sapp_web.name
  }
  alarm_actions = [aws_autoscaling_policy.scaledown.arn]
  depends_on    = [aws_autoscaling_group.sapp_web]
  tags = {
    Name      = "sapp_cpu_low_utilization_${var.environment}"
    component = var.component
  }
}

#------------------------------- Create IAM Profile ---------------------------#

resource "aws_iam_instance_profile" "webserver_profile" {
  name       = "sapp_webserver_${var.environment}_profile"
  role       = aws_iam_role.role.name
  depends_on = [aws_iam_role.role]
}

resource "aws_iam_role" "role" {
  name = "sapp_webserver_${var.environment}_role"
  path = "/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name          = "sapp_webserver_${var.environment}_policy"
  description    = "web server policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "rds:Describe*",
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "web-attach" {
  name          = "sapp_webserver_${var.environment}_policy_attachment"
  roles      = [aws_iam_role.role.name]
  policy_arn = aws_iam_policy.policy.arn
}

################################## EC2 #######################################

################################## CodePipeline #######################################


################################## S3 #######################################

//resource "aws_s3_bucket" "codepipeline_bucket" {
//  bucket = var.bucket_name
//  acl    = "private"
//}

data "aws_s3_bucket" "codepipeline_bucket" {
  bucket = var.bucket_name
}

################################## IAM ROLE #######################################

resource "aws_iam_role" "codepipeline_role" {
  name = "sapp_${var.environment}_codepipeline_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

################################## IAM ROLE POLICY #######################################
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "sapp_${var.environment}_codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::sapp-codepipeline-s3-bucket-jhdgtfr",
        "arn:aws:s3:::sapp-codepipeline-s3-bucket-jhdgtfr/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codedeploy:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

################################## CODEPIPELINE #######################################
resource "aws_codepipeline" "web_pipeline" {
  name = "sapp_${var.environment}_pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = data.aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      category        = "Source"
      owner           = "ThirdParty"
      name            = "Source"
      provider        = "GitHub"
      version         = "1"
      run_order       = 1
      input_artifacts = []
      output_artifacts = [
        "SourceArtifact",
      ]
      configuration = {
        "OAuthToken"           = var.github_token
        "Owner"                = var.repository_owner
        "Repo"                 = var.repository_name
        "Branch"               = var.branch
        "PollForSourceChanges" = "true"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name = "Build"
      category = "Build"
      owner     = "AWS"
      provider  = "CodeBuild"
      run_order = 1
      version   = "1"
      input_artifacts = [
        "SourceArtifact",
      ]
      output_artifacts = [
        "BuildArtifact",
      ]
      configuration = {
        "ProjectName" = "sapp_${var.environment}_build"
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["BuildArtifact"]
      run_order       = 1
      version         = "1"
      configuration = {
        ApplicationName     = aws_codedeploy_app.deployment.name
        DeploymentGroupName = aws_codedeploy_deployment_group.deployment.deployment_group_name
      }
    }
  }
  tags = {
    Environment = var.environment
    component = var.component
  }
}

############################## CodeBuild Project Role ###################################
resource "aws_iam_role" "codebuild" {
  name = join("-", [var.environment, "codebuild"])

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

############################## CodeBuild Project Role POLICY ###################################

resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
POLICY
}

############################## CodeBuild Project ###################################

resource "aws_codebuild_project" "web_build" {
  badge_enabled  = false
  build_timeout  = 60
  name           = "sapp_${var.environment}_build"
  queued_timeout = 480
  service_role   = aws_iam_role.codebuild.arn

  artifacts {
    encryption_disabled    = false
    name                   = "web-build-${var.environment}"
    override_artifact_name = false
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:2.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    type                        = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }

  source {
    #buildspec           = data.template_file.buildspec.rendered
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
  }
}

################################### Code Deploy #############################################

resource "aws_codedeploy_app" "deployment" {
  compute_platform = "Server"
//  name           = join("-", [var.environment, "deployment"])
  name             = "sapp_${var.environment}_deployment"
}

################################### Code Deploy ROLE #############################################
resource "aws_iam_role" "deployment" {
  name = join("-", [var.environment, "deployment-role"])

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

################################### Code Deploy ROLE POLICY #############################################

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.deployment.name
}

################################### Code Deploy  #############################################

resource "aws_codedeploy_deployment_group" "deployment" {
  app_name               = aws_codedeploy_app.deployment.name
//  deployment_group_name  = join("-", [var.environment, "deployment-group"])
  deployment_group_name  = "sapp_${var.environment}_deployment_group"
  service_role_arn       = aws_iam_role.deployment.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime" # AWS defined deployment config
  autoscaling_groups     = [aws_autoscaling_group.sapp_web.name]
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
  load_balancer_info {
    target_group_info {
      name = join("-", [var.environment, "target-group"])
    }
  }
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = 60
    }
  }
  auto_rollback_configuration {
    enabled = true
    events = [
      "DEPLOYMENT_FAILURE",
    ]
  }
}

################################## CodePipeline ########################################
