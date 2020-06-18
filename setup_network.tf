variable "region" {}
variable "vpc_name" {}
variable "subnet_name1" {}
variable "subnet_name2" {}
variable "subnet_name3" {}
variable "internet_gateway_name" {}
variable "route_table_name" {}
variable "vpc_cidr" {}
variable "public_destination_route_cidr" {}
variable "ami_id" { }
variable "key_name" { }

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

  bucket        = "webapp.mitali.manjarekar"
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

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db_subnet_group"
  subnet_ids = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
}

resource "aws_db_instance" "rds_instance" {
  allocated_storage      = 20
  identifier             = "csye6225-su2020"
  multi_az               = false
  db_subnet_group_name   = "${aws_db_subnet_group.db_subnet_group.name}"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  vpc_security_group_ids = ["${aws_security_group.database.id}"]
  skip_final_snapshot    = true
  publicly_accessible    = false
  name                   = "csye6225"
  username               = "csye6225_su2020"
  password               = "Root123#"

  tags = {
  	Name = "rds_instance"
  }
}

resource "aws_instance" "ec2_instance" {
  ami           = "${var.ami_id}"
  instance_type = "t2.micro"
  key_name 		= "${var.key_name}" 
  user_data     = <<-EOF
                      #!/bin/bash
                      echo export host=${aws_db_instance.rds_instance.address} >> /etc/profile
                      echo export S3_BUCKET_NAME=webapp.mitali.manjarekar >> /etc/profile
                      echo export RDS_USER_NAME=csye6225_su2020 >> /etc/profile
                      echo export RDS_PASSWORD=Root123# >> /etc/profile
                      echo export RDS_DB_NAME=csye6225 >> /etc/profile
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
  iam_instance_profile 		  = "${aws_iam_instance_profile.ec2_instance_profile.name}"
  
  tags = {
  	Name = "ec2_instance"
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

resource "aws_iam_role" "ec2_instance_role" {
  name = "EC2-CSYE6225"

  assume_role_policy = <<-EOF
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

resource "aws_iam_role_policy" "new_policy" {
  name        = "WebAppS3"
  role = aws_iam_role.ec2_instance_role.id
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
                "arn:aws:s3:::webapp.mitali.manjarekar",
                "arn:aws:s3:::webapp.mitali.manjarekar/*"
            ]
        }
    ]
}
	EOF
}


resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = "${aws_iam_role.ec2_instance_role.name}"
}

