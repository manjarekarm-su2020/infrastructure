provider "aws" {
  profile = "dev"
  region  = "us-east-1"
}

variable "vpc_name" {}
variable "subnet_name1" {}
variable "subnet_name2" {}
variable "subnet_name3" {}
variable "internet_gateway_name" {}
variable "route_table_name" {}

resource "aws_vpc" "vpc" {
  cidr_block       = "172.16.0.0/16"

  tags = {
    Name = "${var.vpc_name}"
  }
}

data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}"] 
  }
  depends_on = [
    aws_vpc.vpc,
  ]
}

resource "aws_subnet" "subnet1" {
  vpc_id            = "${data.aws_vpc.selected.id}"
  availability_zone = "us-east-1a"
  cidr_block        = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 4, 1)}"
  tags = { 
  	Name = "${var.subnet_name1}"
  }
  depends_on = [
    aws_vpc.vpc,
  ]
}

resource "aws_subnet" "subnet2" {
  vpc_id            = "${data.aws_vpc.selected.id}"
  availability_zone = "us-east-1b"
  cidr_block        = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 4, 2)}"
  tags = { 
  	Name = "${var.subnet_name2}"
  }
  depends_on = [
    aws_vpc.vpc,
  ]
}

resource "aws_subnet" "subnet3" {
  vpc_id            = "${data.aws_vpc.selected.id}"
  availability_zone = "us-east-1c"
  cidr_block        = "${cidrsubnet(data.aws_vpc.selected.cidr_block, 4, 3)}"
  tags = { 
  	Name = "${var.subnet_name3}"
  }
  depends_on = [
    aws_vpc.vpc,
  ]
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${data.aws_vpc.selected.id}"
  tags = {
      Name = "${var.internet_gateway_name}"
  }
  depends_on = [
    aws_vpc.vpc,
  ]
}

#get created gateway info
data "aws_internet_gateway" "created" {
  filter {
    name   = "tag:Name"
    values = ["${var.internet_gateway_name}"] 
  }
  depends_on = [
    aws_internet_gateway.gateway,
  ]
}

#get created subnet1 info
data "aws_subnet" "created_subnet1" {
  filter {
    name   = "tag:Name"
    values = ["${var.subnet_name1}"] 
  }
  depends_on = [
    aws_subnet.subnet1,
  ]
}

#get created subnet2 info
data "aws_subnet" "created_subnet2" {
  filter {
    name   = "tag:Name"
    values = ["${var.subnet_name2}"] 
  }
  depends_on = [
    aws_subnet.subnet2,
  ]
}

#get created subnet3 info
data "aws_subnet" "created_subnet3" {
  filter {
    name   = "tag:Name"
    values = ["${var.subnet_name3}"] 
  }
  depends_on = [
    aws_subnet.subnet3,
  ]
}

resource "aws_route_table" "route_table" {
  vpc_id = "${data.aws_vpc.selected.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${data.aws_internet_gateway.created.id}"
  }

  tags = {
    Name = "${var.route_table_name}"
  }
}

#get created route table info
data "aws_route_table" "created_route_table" {
  filter {
    name   = "tag:Name"
    values = ["${var.route_table_name}"] 
  }
  depends_on = [
    aws_route_table.route_table,
  ]
}

resource "aws_route_table_association" "route_subnet1" {
  subnet_id      = "${data.aws_subnet.created_subnet1.id}"
  route_table_id = "${data.aws_route_table.created_route_table.id}"
}

resource "aws_route_table_association" "route_subnet2" {
  subnet_id      = "${data.aws_subnet.created_subnet2.id}"
  route_table_id = "${data.aws_route_table.created_route_table.id}"
}

resource "aws_route_table_association" "route_subnet3" {
  subnet_id      = "${data.aws_subnet.created_subnet3.id}"
  route_table_id = "${data.aws_route_table.created_route_table.id}"
}
