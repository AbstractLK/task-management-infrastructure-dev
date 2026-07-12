provider "aws" {
    region = "ap-southeast-1"
}

resource "aws_vpc" "project_vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "project-vpc"
    }
}

resource "aws_subnet" "project_subnet" {
    vpc_id                  = aws_vpc.project_vpc.id
    cidr_block              = "10.0.1.0/24"
    map_public_ip_on_launch = true

    tags = {
        Name = "project-subnet"
    }
}

resource "aws_internet_gateway" "project_igw" {
    vpc_id = aws_vpc.project_vpc.id

    tags = {
        Name = "project-igw"
    }
}

resource "aws_route_table" "project_rt" {
    vpc_id = aws_vpc.project_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.project_igw.id
    }

    tags = {
      Name = "project-rt"
    }
}

resource "aws_route_table_association" "public_assoc" {
    subnet_id = aws_subnet.project_subnet.id
    route_table_id = aws_route_table.project_rt.id
}

resource "aws_security_group" "project_sg" {
    vpc_id = aws_vpc.project_vpc.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "project_ec2" {
    ami = "ami-095bd4a11ce8746c0"
    instance_type = "t3.micro"
    subnet_id = aws_subnet.project_subnet.id
    vpc_security_group_ids = [aws_security_group.project_sg.id]
    key_name = "devops-kp"

    tags = {
        Name = "project-ec2"
    }

    user_data = <<-EOF
        #!/bin/bash
        yum update -y
        dnf install -y docker

        systemctl start docker
        systemctl enable docker

        usermod -aG docker ec2-user

        mkdir -p /usr/libexec/docker/cli-plugins/
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/libexec/docker/cli-plugins/docker-compose
        chmod +x /usr/libexec/docker/cli-plugins/docker-compose
        EOF
}