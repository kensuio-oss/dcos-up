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
}
