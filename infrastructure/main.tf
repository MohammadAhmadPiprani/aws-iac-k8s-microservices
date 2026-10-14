resource "aws_vpc" "first_vpc" {
  cidr_block          = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                = { Name = "my_vpc" }

}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.first_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "my_subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.first_vpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.first_vpc.id

  route {
    cidr_block          = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id
  route_table_id  = aws_route_table.rt.id

}

resource "aws_security_group" "sec_grp" {
  vpc_id = aws_vpc.first_vpc.id
  name   = "my_security_group"

  ingress {
    description = "SSH"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks  = [var.my_ip]

  }

  ingress {
    description = "App by ingress port-forward"
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks  = [var.my_ip]

  }

  egress {
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_blocks = ["0.0.0.0/0"]

  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name  = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "ec2" {
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.sec_grp.id]
  ami           = data.aws_ami.ubuntu.id
  key_name      = var.key_pair
  instance_type = var.instance_type
  user_data     = file("${path.module}/con.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"

  }
  tags = { Name = "my_ec2" }
}
