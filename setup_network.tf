variable "region" { }
variable "vpc_name" {}
variable "subnet_name1" {}
variable "subnet_name2" {}
variable "subnet_name3" {}
variable "internet_gateway_name" {}
variable "route_table_name" {}
variable "vpc_cidr" {}
variable "public_destination_route_cidr" {}
variable "ami_id" {}
variable "key_name" {}
variable "s3_bucket_name" {}
variable "rds_username" {}
variable "rds_password" {}
variable "rds_db_name" {}
variable "rds_identifier" {}
variable "account_num" {}


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
    description = "allow tcp traffic on port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow tcp traffic on port 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "allow tcp traffic on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow tcp traffic on port 3000"
    from_port   = 3000
    to_port     = 3000
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
    cidr_blocks     = ["0.0.0.0/0"]
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

  bucket        = "webapp.mitali.manjrekar"
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

  bucket        = "codedeploy.mitalimanjrekar.me"
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
    Name = "codedeploy_bucket"
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

resource "aws_instance" "ec2_instance" {
  ami           = "${var.ami_id}"
  instance_type = "t2.micro"
  key_name    = "${var.key_name}" 
  user_data     = <<-EOF
                      #!/bin/bash
                      echo export host=${aws_db_instance.rds_instance.address} >> /etc/profile
                      echo export S3_BUCKET_NAME=${var.s3_bucket_name} >> /etc/profile
                      echo export RDS_USER_NAME=${var.rds_username} >> /etc/profile
                      echo export RDS_PASSWORD=${var.rds_password} >> /etc/profile
                      echo export RDS_DB_NAME=${var.rds_db_name} >> /etc/profile
                      echo export PORT=3000 >> /etc/profile
          EOF

  ebs_block_device {
      device_name           = "/dev/sda1"
      volume_size           = "20"
      volume_type           = "gp2"
      delete_on_termination = "true"
  }
  
  vpc_security_group_ids = ["${aws_security_group.application.id}"]

  associate_public_ip_address = true
  source_dest_check           = false
  subnet_id                   = "${aws_subnet.subnet1.id}"
  depends_on                  = ["aws_db_instance.rds_instance","aws_s3_bucket.s3_bucket"]
  iam_instance_profile      = aws_iam_instance_profile.ec2_instance_profile.name
  
  tags = {
    Name = "target_ec2_instance"
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
                "s3:List*"
            ],
            "Resource": [
              "arn:aws:s3:::codedeploy.mitalimanjrekar.me",
              "arn:aws:s3:::codedeploy.mitalimanjrekar.me/*"
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
                "arn:aws:codedeploy:${var.region}:${var.account_num}:application:csye6225-webapp"
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
  name        = "circleci-ec2-ami"
  description = "EC2 access for user circleci"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
      "Effect": "Allow",
      "Action" : [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource" : "*"
  }]
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
                "iam:PassRole"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::codedeploy.mitalimanjrekar.me",
              "arn:aws:s3:::codedeploy.mitalimanjrekar.me/*",
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
                "arn:aws:s3:::webapp.mitali.manjrekar",
                "arn:aws:s3:::webapp.mitali.manjrekar/*"
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
                "ec2:*",
                "s3:*"
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
