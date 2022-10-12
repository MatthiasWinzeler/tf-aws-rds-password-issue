provider "aws" {
  region = "us-east-1"
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_instance" "postgres" {
  engine                 = "postgres"
  engine_version         = "13.7"
  instance_class         = "db.t4g.micro"
  db_name                = "rdsissue"
  username               = "rdsissueadmin"
  password               = random_password.db.result
  apply_immediately      = true
  publicly_accessible    = true
  allocated_storage      = 10
  db_subnet_group_name   = aws_db_subnet_group.subnet_group.name
  vpc_security_group_ids = [aws_security_group.db.id]

  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_db_subnet_group" "subnet_group" {
  name       = "rds-issue-subnet-group"
  subnet_ids = aws_subnet.subnet[*].id
}

resource "aws_security_group" "db" {
  name   = "rds-issue-sg"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "postgres_from_internet" {
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.db.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "db-from-internet"
}

locals {
  vpc_cidr = "192.168.0.0/24"
}

resource "aws_vpc" "vpc" {
  cidr_block = local.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "rds-issue"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "subnet" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 3, count.index)
  // creates subnet with size /27 (30 hosts, should be more than enough)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "rds-issue-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "rds-issue-igw"
  }
}

resource "aws_default_route_table" "vpc_default_route_table" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rds-issue-default-route-table"
  }
}