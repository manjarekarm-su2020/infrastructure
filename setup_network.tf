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
variable "vpc_cidr" {}
variable "public_destination_route_cidr" {}

#172.16.0.0/16
resource "aws_vpc" "vpc" {
  cidr_block       = "${var.vpc_cidr}"

  tags = {
    Name = "${var.vpc_name}"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = "us-east-1a"
  cidr_block        = "${cidrsubnet(aws_vpc.vpc.cidr_block, 4, 1)}"
  map_public_ip_on_launch = true
  tags = { 
    Name = "${var.subnet_name1}"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = "us-east-1b"
  cidr_block        = "${cidrsubnet(aws_vpc.vpc.cidr_block, 4, 2)}"
  map_public_ip_on_launch = true
  tags = { 
    Name = "${var.subnet_name2}"
  }
}

resource "aws_subnet" "subnet3" {
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = "us-east-1c"
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
