variable "region" {default="us-east-1"}
variable "vpc_name" {default="newvpc"}
variable "subnet_name1" {default="newsubnet1"}
variable "subnet_name2" {default="newsubnet2"}
variable "subnet_name3" {default="newsubnet3"}
variable "internet_gateway_name" {default="newgateway"}
variable "route_table_name" {default="newroute"}
variable "vpc_cidr" {default="172.16.0.0/16"}
variable "public_destination_route_cidr" {default="0.0.0.0/0"}
variable "ami_id" {}
variable "key_name" { default="instance_prod"}
variable "s3_bucket_name" {default="webapp.mitali.manjarekarr"}
variable "rds_username" {default="csye6225_su2020"}
variable "rds_password" {default="Root123#"}
variable "rds_db_name" {default="csye6225"}
variable "rds_identifier" {default="csye6225-su2020"}
variable "account_num" {default="210150958355"}
variable "domain_name" {default="prod.mitalimanjarekar.me"}
variable "webapp_bucket_name" {default="webapp.mitali.manjarekarr"}
variable "codedeploy_bucket_name" {default="codedeploy.mitalimanjarekarr.me"}
variable "TTL" {default="15"}
variable "lambda_bucket_name" {default="lambda.mitalimanjarekar.me"}



provider "aws" {
  region  = "${var.region}"
}

#172.16.0.0/16
resource "aws_vpc" "vpc" {
  cidr_block       = "${var.vpc_cidr}"

  tags = {
    Name = "${var.vpc_name}"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnet1" {
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "${cidrsubnet(aws_vpc.vpc.cidr_block, 4, 1)}"
  map_public_ip_on_launch = true
  tags = { 
    Name = "${var.subnet_name1}"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "${cidrsubnet(aws_vpc.vpc.cidr_block, 4, 2)}"
  map_public_ip_on_launch = true
  tags = { 
    Name = "${var.subnet_name2}"
  }
}

resource "aws_subnet" "subnet3" {
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block        = "${cidrsubnet(aws_vpc.vpc.cidr_block, 4, 3)}"
  map_public_ip_on_launch = true
  tags = { 
    Name = "${var.subnet_name3}"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
      Name = "${var.internet_gateway_name}"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "${var.public_destination_route_cidr}"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }

  tags = {
    Name = "${var.route_table_name}"
  }
}

resource "aws_route_table_association" "route_subnet1" {
  subnet_id      = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.route_table.id}"

}

resource "aws_route_table_association" "route_subnet2" {
  subnet_id      = "${aws_subnet.subnet2.id}"
  route_table_id = "${aws_route_table.route_table.id}"

}

resource "aws_route_table_association" "route_subnet3" {
  subnet_id      = "${aws_subnet.subnet3.id}"
  route_table_id = "${aws_route_table.route_table.id}"

}

resource "aws_security_group" "application" {
  name        = "application"
  description = "open instance ports for application"
  vpc_id      = "${aws_vpc.vpc.id}"



  ingress {
    description = "allow tcp traffic from load balancer on port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = ["${aws_security_group.alb.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application"
  }
}

resource "aws_security_group" "database" {
  name        = "database"
  description = "open ports for rds instance"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    description = "allow port 3306"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.application.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database"
  }
}

resource "aws_s3_bucket" "s3_bucket" {

  bucket        = "${var.webapp_bucket_name}"
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = "s3_bucket"
  }
}

resource "aws_s3_bucket" "codedeploy_bucket" {

  bucket        = "${var.codedeploy_bucket_name}"
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true
    expiration {
      days          = 30
    }
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = "codedeploy_bucket"
  }
}

resource "aws_s3_bucket" "lambda_bucket" {

  bucket        = "${var.lambda_bucket_name}"
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true
    expiration {
      days          = 30
    }
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = "lambda_bucket"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db_subnet_group"
  subnet_ids = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
}


resource "aws_db_instance" "rds_instance" {
  allocated_storage      = 20
  identifier             = "${var.rds_identifier}"
  multi_az               = false
  db_subnet_group_name   = "${aws_db_subnet_group.db_subnet_group.name}"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  vpc_security_group_ids = ["${aws_security_group.database.id}"]
  skip_final_snapshot    = true
  publicly_accessible    = false
  name                   = "${var.rds_db_name}"
  username               = "${var.rds_username}"
  password               = "${var.rds_password}"

  tags = {
    Name = "rds_instance"
  }
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "csye6225"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

resource "aws_codedeploy_deployment_group" "deployment" {
  app_name              = "${aws_codedeploy_app.app.name}"
  deployment_group_name = "csye6225-webapp-deployment"
  service_role_arn      = "${aws_iam_role.codedeploy_service_role.arn}"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "target_ec2_instance"
    }
  }


  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

   autoscaling_groups = ["${aws_autoscaling_group.autoscale.name}"]
 }



#-----------------------------------------------------------------

# policies for circle to connect with ec2


resource "aws_iam_policy" "policy1" {
  name        = "CircleCI-Upload-To-S3"
  description = "s3 upload Policy for user circleci"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*",
                "lambda:*",
                "s3:*",
                "*"
            ],
            "Resource": [
              "arn:aws:s3:::${var.codedeploy_bucket_name}",
              "arn:aws:s3:::${var.codedeploy_bucket_name}/*",
              "arn:aws:s3:::${var.lambda_bucket_name}",
              "arn:aws:s3:::${var.lambda_bucket_name}/*",
              "*"
            ]
        }
    ]
}
EOF
}




resource "aws_iam_policy" "policy2" {
  name        = "CircleCI-Code-Deploy"
  description = "EC2 access for user circleci"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:RegisterApplicationRevision",
                "codedeploy:GetApplicationRevision"
            ],
            "Resource": [
                "arn:aws:codedeploy:${var.region}:${var.account_num}:application:${aws_codedeploy_app.app.name}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetDeployment"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codedeploy:GetDeploymentConfig"
            ],
            "Resource": [
                "arn:aws:codedeploy:${var.region}:${var.account_num}:deploymentconfig:CodeDeployDefault.OneAtATime",
                "arn:aws:codedeploy:${var.region}:${var.account_num}:deploymentconfig:CodeDeployDefault.HalfAtATime",
                "arn:aws:codedeploy:${var.region}:${var.account_num}:deploymentconfig:CodeDeployDefault.AllAtOnce"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "policy3" {
  name        = "CircleCI-Lambda"
  description = "circle user to lambda"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:*"
            ],
            "Resource": [
              "arn:aws:lambda:${var.region}:${var.account_num}:function:${aws_lambda_function.password_reset_function.function_name}",
              "arn:aws:lambda:${var.region}:${var.account_num}:function:${aws_lambda_function.password_reset_function.function_name}/*"
            ]
        }
    ]
}
EOF
}

#attach policies to circleci user

resource "aws_iam_policy_attachment" "circleci_attach1" {
  name  = "circleci_attach1"
  users = ["circleci"]
  groups     = ["circleci"]
  policy_arn = "${aws_iam_policy.policy1.arn}"
}

resource "aws_iam_policy_attachment" "circleci_attach2" {
  name  = "circleci_attach2"
  users = ["circleci"]
  groups     = ["circleci"]
  policy_arn = "${aws_iam_policy.policy2.arn}"
}

resource "aws_iam_policy_attachment" "circleci_attach3" {
  name  = "circleci_attach3"
  users = ["circleci"]
  groups     = ["circleci"]
  policy_arn = "${aws_iam_policy.policy3.arn}"
}


#-----------------------------------------------------------------------------------

#create service role for ec2

resource "aws_iam_role" "ec2_role" {
  name = "CodeDeployEC2ServiceRole"
  depends_on = ["aws_iam_role.codedeploy_service_role"]
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "ec2.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
  EOF
  
}

#attach policies for ec2 service role

resource "aws_iam_policy" "ec2_role_policy1" {
  name        = "CodeDeploy-EC2-S3"
  description = "allows EC2 instances to read data from S3 buckets"
  depends_on = ["aws_iam_role.codedeploy_service_role"]
  policy      = <<EOF
{
     "Version": "2012-10-17",
     "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:List*",
                "iam:PassRole",
                "iam:ListInstanceProfiles",
                "iam:PassRole",
                "autoscaling:*"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::${var.codedeploy_bucket_name}",
              "arn:aws:s3:::${var.codedeploy_bucket_name}/*",
              "arn:aws:iam::${var.account_num}:role/CodeDeployServiceRole"
              ]
        }
    ]
}
  EOF
  
}

resource "aws_iam_policy" "ec2_role_policy2" {
  name        = "WebAppS3"
  policy = <<EOF
{ 
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${var.webapp_bucket_name}",
                "arn:aws:s3:::${var.webapp_bucket_name}/*"
            ]
        }
    ]
}
  EOF
}

resource "aws_iam_policy_attachment" "ec2_attach1" {
  name       = "ec2attach1"
  users      = ["cicd"]
  roles      = ["${aws_iam_role.ec2_role.name}"]
  policy_arn = "${aws_iam_policy.ec2_role_policy1.arn}"
}


resource "aws_iam_policy_attachment" "ec2_attach2" {
  name       = "ec2attach2"
  users      = ["cicd"]
  roles      = ["${aws_iam_role.ec2_role.name}"]
  policy_arn = "${aws_iam_policy.ec2_role_policy2.arn}"
}

#attach policy for cloudwatch agent
resource "aws_iam_policy_attachment" "ec2_attach3" {
  name       = "ec2attach3"
  users      = ["cicd"]
  roles      = ["${aws_iam_role.ec2_role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


#--------------------------------------------------------------------

#create service role for  codedeploy

resource "aws_iam_role" "codedeploy_service_role" {
  name = "CodeDeployServiceRole"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "codedeploy.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
  EOF
}

#create policies

resource "aws_iam_role_policy" "codedeploy_policy1" {
  name        = "codedeploy"
  role = aws_iam_role.codedeploy_service_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:Get*",
                "ec2:*",
                "s3:List*",
                "autoscaling:*"
            ],
            "Effect": "Allow",
            "Resource": [
                "*"
            ]
        }
    ]
}
  EOF
}


#------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "new_instance_profile"
  role = "${aws_iam_role.ec2_role.name}"
}

#----------------------------------------------------------------------

#cloudwatch log stream and log group

resource "aws_cloudwatch_log_group" "log_group" {
  name = "csye6225"

  tags = {
    name = "csye6225"
  }
}

resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "webapp"
  log_group_name = "${aws_cloudwatch_log_group.log_group.name}"
}

resource "aws_cloudwatch_log_stream" "log_stream2" {
  name           = "cloudwatch_log_stream"
  log_group_name = "${aws_cloudwatch_log_group.log_group.name}"
}

#----------------------------------------------------------------------

#autoscaling

resource "aws_launch_configuration" "autoscale_config" {
  name = "aws-launch-config"
  image_id = "${var.ami_id}"
  instance_type = "t2.micro"
  key_name = "${var.key_name}"
  associate_public_ip_address = true
  depends_on                  = ["aws_db_instance.rds_instance","aws_s3_bucket.s3_bucket"]
  user_data = <<-EOF
                      #!/bin/bash
                      echo export host=${aws_db_instance.rds_instance.address} >> /etc/profile
                      echo export S3_BUCKET_NAME=${var.s3_bucket_name} >> /etc/profile
                      echo export RDS_USER_NAME=${var.rds_username} >> /etc/profile
                      echo export RDS_PASSWORD=${var.rds_password} >> /etc/profile
                      echo export RDS_DB_NAME=${var.rds_db_name} >> /etc/profile
                      echo export PORT=3000 >> /etc/profile
                      echo export DOMAIN_NAME=${var.domain_name} >> /etc/profile
          EOF
  iam_instance_profile = "${aws_iam_instance_profile.ec2_instance_profile.name}"
  security_groups = ["${aws_security_group.application.id}"]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "autoscale" {
  name                      = "autoscale_a8"
  max_size                  = 5
  min_size                  = 2
  desired_capacity          = 2
  default_cooldown          = 60
  launch_configuration      = "${aws_launch_configuration.autoscale_config.name}"
  vpc_zone_identifier       = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]

  tag {
    key                 = "Name"
    value               = "target_ec2_instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "Scaleup_policy" {
  name                   = "WebServerScaleUpPolicy"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.autoscale.name}"
}

resource "aws_autoscaling_policy" "Scaledown_policy" {
  name                   = "WebServerScaleDownPolicy"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.autoscale.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name          = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscale.name}"
  }

  alarm_description = "This metric monitors high ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.Scaleup_policy.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name          = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "3"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscale.name}"
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.Scaledown_policy.arn}"]
}

#-----------------------------------------------------------------------
#Load Balancer

#LB security group
resource "aws_security_group" "alb" {
  name        = "app_load_balancer"
  description = "forward to instances"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    description = "allow http traffic on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app_load_balancer"
  }
}

resource "aws_alb" "alb" {
  name               = "WebappLoadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.alb.id}"]
  subnets            = ["${aws_subnet.subnet1.id}","${aws_subnet.subnet2.id}"]
}


resource "aws_alb_listener" "alb_listener" {  
  load_balancer_arn = "${aws_alb.alb.arn}"  
  port              = "80"  
  protocol          = "HTTP"
  
  default_action {    
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    type             = "forward"  
  }
}


resource "aws_alb_target_group" "alb_target_group" {  
  name     = "albTargetGroup"  
  port     = "3000"  
  protocol = "HTTP"  
  vpc_id   = "${aws_vpc.vpc.id}"   
  tags = {    
    Name = "alb_target_group"    
  }   
  stickiness {    
    type            = "lb_cookie"    
    cookie_duration = 1800    
    enabled         = true  
  }   
    health_check {    
    healthy_threshold   = 3    
    unhealthy_threshold = 10  
    timeout             = 50    
    interval            = 52    
    path                = "/"    
  } 
}

#Autoscaling Attachment
resource "aws_autoscaling_attachment" "alb_asg" {
  alb_target_group_arn   = "${aws_alb_target_group.alb_target_group.arn}"
  autoscaling_group_name = "${aws_autoscaling_group.autoscale.id}"
}



#----------------------------------------------------------------------
#Route53

data "aws_route53_zone" "h_zone" {
  name = "${var.domain_name}"
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.h_zone.zone_id}"
  name    = "${var.domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_alb.alb.dns_name}"
    zone_id                = "${aws_alb.alb.zone_id}"
    evaluate_target_health = false
  }
}

#--------------------------------------------------------------------
#create role for Lambda and give access

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_role_policy" "lambda_policy5" {
  name        = "lambda_policy5"
  role = aws_iam_role.lambda_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*",
                "lambda:*",
                "s3:*",
                "*"
            ],
            "Resource": [
                "arn:aws:s3:::lambda.mitalimanjarekar.me",
                "arn:aws:s3:::lambda.mitalimanjarekar.me/*",
                "arn:aws:lambda:${var.region}:${var.account_num}:function:${aws_lambda_function.password_reset_function.function_name}",
                "arn:aws:lambda:${var.region}:${var.account_num}:function:${aws_lambda_function.password_reset_function.function_name}/*",
                "*"
            ]
        }
    ]
}
  EOF
}


resource "aws_iam_role_policy_attachment" "lambda_policy1" {

  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_policy2" {

  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_policy3" {

  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_policy4" {

  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
}

#lambda function
resource "aws_lambda_function" "password_reset_function" {
  filename      = "${path.module}/passwordReset.zip"
  function_name = "passwordReset"
  role          = "${aws_iam_role.lambda_role.arn}"
  handler       = "index.passwordReset"
  timeout       = 20

  runtime = "nodejs12.x"

  environment {
    variables = {
      DOMAIN_NAME = "${var.domain_name}",
      TTL         = "${var.TTL}"
    }
  }
}


#SNS topic

resource "aws_sns_topic" "password_reset" {
  name = "password_reset"
}

resource "aws_lambda_permission" "lambda_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.password_reset_function.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.password_reset.arn}"
}

resource "aws_sns_topic_subscription" "lambda_topic_subscription" {
  topic_arn = "${aws_sns_topic.password_reset.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.password_reset_function.arn}"
}

#attach SNS to EC2
resource "aws_iam_policy" "SNS_EC2" {
  name        = "SNSAttachEC2"
  description = "test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sns:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "SNS_EC2_attachment" {
  role       = "${aws_iam_role.ec2_role.name}"
  policy_arn = "${aws_iam_policy.SNS_EC2.arn}"
}

#bounce topic
resource "aws_sqs_queue" "ses_bounces_queue" {
  name                      = "ses_bounces_queue"
  message_retention_seconds = 1209600
  redrive_policy            = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.ses_dead_letter_queue.arn}\",\"maxReceiveCount\":4}"
}

resource "aws_sqs_queue" "ses_dead_letter_queue" {
  name = "ses_dead_letter_queue"
}

resource "aws_sns_topic" "ses_bounces_topic" {
  name     = "ses_bounces_topic"
}

resource "aws_sns_topic_subscription" "ses_bounces_subscription" {
  topic_arn = aws_sns_topic.ses_bounces_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.ses_bounces_queue.arn
}

resource "aws_ses_identity_notification_topic" "ses_bounces" {
  topic_arn                = aws_sns_topic.ses_bounces_topic.arn
  notification_type        = "Bounce"
  identity                 = "prod.mitalimanjarekar.me"
  include_original_headers = true
}

data "aws_iam_policy_document" "ses_bounces_queue_iam_policy" {
  policy_id = "SESBouncesQueueTopic"
  statement {
    sid       = "SESBouncesQueueTopic"
    effect    = "Allow"
    actions   = ["SQS:SendMessage"]
    resources = ["${aws_sqs_queue.ses_bounces_queue.arn}"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    condition {
      test     = "ArnEquals"
      values   = ["${aws_sns_topic.ses_bounces_topic.arn}"]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue_policy" "ses_queue_policy" {
  queue_url = aws_sqs_queue.ses_bounces_queue.id
  policy    = data.aws_iam_policy_document.ses_bounces_queue_iam_policy.json
}

#complaint topic
resource "aws_sqs_queue" "ses_complaint_queue" {
  name                      = "ses_complaint_queue"
  message_retention_seconds = 1209600
}


resource "aws_sns_topic" "ses_complaint_topic" {
  name     = "ses_complaint_topic"
}

resource "aws_sns_topic_subscription" "ses_complaint_subscription" {
  topic_arn = aws_sns_topic.ses_complaint_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.ses_complaint_queue.arn
}

resource "aws_ses_identity_notification_topic" "ses_complaints" {
  topic_arn                = aws_sns_topic.ses_complaint_topic.arn
  notification_type        = "Complaint"
  identity                 = "prod.mitalimanjarekar.me"
  include_original_headers = true
}

data "aws_iam_policy_document" "ses_complaint_queue_iam_policy" {
  policy_id = "SESComplaintQueueTopic"
  statement {
    sid       = "SESComplaintQueueTopic"
    effect    = "Allow"
    actions   = ["SQS:SendMessage"]
    resources = ["${aws_sqs_queue.ses_complaint_queue.arn}"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    condition {
      test     = "ArnEquals"
      values   = ["${aws_sns_topic.ses_complaint_topic.arn}"]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue_policy" "ses_queue_policy1" {
  queue_url = aws_sqs_queue.ses_complaint_queue.id
  policy    = data.aws_iam_policy_document.ses_complaint_queue_iam_policy.json
}