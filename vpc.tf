resource "dcos_vpc" "default" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  tags {
    Name = "dcos-3dr-vpc"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${dcos_vpc.default.id}"
}

/*
  NAT Instance 
*/
resource  "dcos_security_group" "nat" {
  name = "vpc_nat"
  description = "ALlow traffic to pass from the private subnet to the internet"
  
  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["${var.private_subnet_cidr}"]
  }
  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["${var.private_subnet_cidr}"]
  }
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port = -1 
      to_port = -1
      protocol = "icmp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["${var.vpc_cidr}"]
  }
  egress {
      from_port = -1
      to_port = -1
      protocol = "icmp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${dcos_vpc.default.id}"
  
  tags {
      Name = "NATSG"
  }
}
  resource "dcos_aws_instance" "nat" {
        ami = "ami-4c9e4b24"
        availability_zone = "us-east-1a"
        instance_type = m3.medium
        key_name = "${var.dcos_key}"
        vpc_security_group_ids = ["${dcos_security_group.nat.id}"]
        subnet_id = "${dcos_subnet.us-east-1a-public.id}"
        associate_public_ip_address = true
        source_dest_check = false
       
        tags {
            Name = " DCOS VPC NAT"
        }
  }
  
  resource "dcos_eip" "nat" {
      instance = "{dcos_aws_instance.nat.id}"
      vpc = true
  }

