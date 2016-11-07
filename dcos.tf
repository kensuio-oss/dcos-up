variable "infra_name" {
  type = "string"
  default = "test_infra"
}

variable "region" {
  type = "string"
  default = "us-east-1"
}

variable "availability_zone" {
  type = "string"
  default = "a"
}

variable "spot_price" {
  default = "0.05"
}

variable "bootstrap_port" {
  type = "string"
  default = "10000"
}

variable "ami_ids" {
  type = "map"
  default {
    us-east-1 = "ami-6d1c2007"
    us-west-1 = "ami-af4333cf"
    us-west-2 = "ami-d2c924b2"
    eu-central-1 = "ami-9bf712f4"
    eu-west-1 = "ami-7abd0209"
    ap-southeast-1 = "ami-f068a193"
    ap-southeast-2 = "ami-fedafc9d"
    ap-northeast-1 = "ami-eec1c380"
    ap-northeast-2 = "ami-c74789a9"
    sa-east-1 = "ami-26b93b4a"
  }
}

variable "instance_types" {
  type = "map"
  default = {
    bootstrap    = "m3.large"
    master       = "m3.large"
    slave        = "m3.large"
    slave_public = "m3.large"
  }  
}

variable "instance_counts" {
  type = "map"
  default = {
    master       = 1
    slave        = 2
    slave_public = 1
  }
}

variable "provisioner" {
  type = "map"
  default = {
    username = "centos"
    key_name = "dcos-centos"
    directory = "/home/centos/provision"
  }
}

resource "aws_security_group" "ssh_access" {
  name = "${var.infra_name}_ssh_access"
  description = "Allow all ssh access"
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "consul_member" {
  name = "${var.infra_name}_consul_member"
  description = "Consul member"
  ingress {
    from_port = 8300
    to_port = 8302
    protocol = "tcp"
    self = true
  }
  ingress {
    from_port = 8300
    to_port = 8302
    protocol = "udp"
    self = true
  }
  ingress {
    from_port = 8400
    to_port = 8400
    protocol = "tcp"
    self = true
  }
  ingress {
    from_port = 8400
    to_port = 8400
    protocol = "udp"
    self = true
  }
  ingress {
    from_port = 8500
    to_port = 8500
    protocol = "tcp"
    self = true
  }
  ingress {
    from_port = 8600
    to_port = 8600
    protocol = "tcp"
    self = true
  }
#  ingress {
#    from_port = 8600
#    to_port = 8600
#    protocol = "udp"
#    self = true
#  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bootstrap_http" {
  name = "${var.infra_name}_bootstrap_http"
  description = "DCOS bootstrap machine HTTP access"
  ingress {
    from_port = 2181
    to_port = 2181
    protocol = "tcp"
    security_groups = ["${aws_security_group.dcos_member.id}"]
  }
  ingress {
    from_port = "${var.bootstrap_port}"
    to_port = "${var.bootstrap_port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.dcos_member.id}"]
  }
}

resource "aws_security_group" "dcos_member" {
  name = "${var.infra_name}_dcos_member"
  description = "DCOS cluster member"
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }
}

resource "aws_security_group" "dcos_slave" {
  name = "${var.infra_name}_dcos_slave"
  description = "DCOS slave access"
  ingress {
    from_port = 1
    to_port = 21
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 23
    to_port = 5050
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 5052
    to_port = 32000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dcos_slave_public" {
  name = "${var.infra_name}_dcos_slave_public"
  description = "DCOS slave public access"
  ingress {
    from_port = 1
    to_port = 21
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 23
    to_port = 5050
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 5052
    to_port = 32000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dcos_master_insecure" {
  name = "${var.infra_name}_dcos_master_insecure"
  description = "DCOS master, normally authentication required"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 5050
    to_port = 5050
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8181
    to_port = 8181
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# INSTANCES:

resource "aws_spot_instance_request" "dcos_bootstrap" {
  spot_price = "${var.spot_price}"
  wait_for_fulfillment = true
  associate_public_ip_address = true
  ami = "${lookup(var.ami_ids,var.region)}"
  instance_type = "${lookup(var.instance_types,"bootstrap")}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${lookup(var.provisioner,"key_name")}"
  tags {
    Name = "${var.infra_name}_dcos_bootstrap"
  }
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.bootstrap_http.id}"]
  connection {
    type = "ssh"
    user = "${lookup(var.provisioner,"username")}"
    private_key = "${file("keys/${lookup(var.provisioner,"key_name")}.pem")}"
    agent = false
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${lookup(var.provisioner,"directory")}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${self.private_dns} > ${lookup(var.provisioner,"directory")}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export EXPECTED_MASTER_COUNT=${lookup(var.instance_counts, "master")} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export EXPECTED_AGENT_COUNT=${lookup(var.instance_counts, "slave") + lookup(var.instance_counts, "slave_public")} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export DATACENTER=${var.infra_name} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export NODE_NAME=dcos_bootstrap >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IS_CONSUL_SERVER=true >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IS_BOOTSTRAP_SERVER=true >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${lookup(var.provisioner,"directory")}/vars"
    ]
  }
  provisioner "file" {
    source = "${path.module}/provision/"
    destination = "${lookup(var.provisioner,"directory")}"
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${lookup(var.provisioner,"directory")} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${lookup(var.provisioner,"directory")} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}

resource "aws_spot_instance_request" "dcos_master_node" {
  spot_price = "${var.spot_price}"
  wait_for_fulfillment = true
  associate_public_ip_address = true
  count = "${lookup(var.instance_counts,"master")}"
  ami = "${lookup(var.ami_ids,var.region)}"
  instance_type = "${lookup(var.instance_types,"master")}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${lookup(var.provisioner,"key_name")}"
  tags {
    Name = "${var.infra_name}_dcos_master_node-${count.index}"
  }
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.dcos_member.id}",
                             "${aws_security_group.dcos_master_insecure.id}" ]
  connection {
    user = "${lookup(var.provisioner,"username")}"
    key_file = "${path.module}/keys/${lookup(var.provisioner,"key_name")}.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${lookup(var.provisioner,"directory")}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${aws_spot_instance_request.dcos_bootstrap.private_dns} > ${lookup(var.provisioner,"directory")}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export DATACENTER=${var.infra_name} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export NODE_NAME=dcos_master_node-${count.index} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export DCOS_NODE_TYPE=master >> ${lookup(var.provisioner,"directory")}/vars"
    ]
  }
  provisioner "file" {
    source = "${path.module}/provision/"
    destination = "${lookup(var.provisioner,"directory")}"
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${lookup(var.provisioner,"directory")} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${lookup(var.provisioner,"directory")} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}

resource "aws_spot_instance_request" "dcos_slave_node" {
  spot_price = "${var.spot_price}"
  wait_for_fulfillment = true
  associate_public_ip_address = true
  count = "${lookup(var.instance_counts,"slave")}"
  ami = "${lookup(var.ami_ids,var.region)}"
  instance_type = "${lookup(var.instance_types,"slave")}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${lookup(var.provisioner,"key_name")}"
  tags {
    Name = "${var.infra_name}_dcos_slave_node-${count.index}"
  }
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.dcos_member.id}",
                             "${aws_security_group.dcos_slave.id}" ]
  connection {
    user = "${lookup(var.provisioner,"username")}"
    key_file = "${path.module}/keys/${lookup(var.provisioner,"key_name")}.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${lookup(var.provisioner,"directory")}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${aws_spot_instance_request.dcos_bootstrap.private_dns} > ${lookup(var.provisioner,"directory")}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export DATACENTER=${var.infra_name} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export NODE_NAME=dcos_slave_node-${count.index} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export DCOS_NODE_TYPE=slave >> ${lookup(var.provisioner,"directory")}/vars"
    ]
  }
  provisioner "file" {
    source = "${path.module}/provision/"
    destination = "${lookup(var.provisioner,"directory")}"
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${lookup(var.provisioner,"directory")} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${lookup(var.provisioner,"directory")} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}

resource "aws_spot_instance_request" "dcos_slave_public_node" {
  spot_price = "${var.spot_price}"
  wait_for_fulfillment = true
  associate_public_ip_address = true
  count = "${lookup(var.instance_counts,"slave_public")}"
  ami = "${lookup(var.ami_ids,var.region)}"
  instance_type = "${lookup(var.instance_types,"slave_public")}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${lookup(var.provisioner,"key_name")}"
  tags {
    Name = "${var.infra_name}_dcos_slave_public_node-${count.index}"
  }
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.dcos_member.id}",
                             "${aws_security_group.dcos_slave_public.id}" ]
  connection {
    user = "${lookup(var.provisioner,"username")}"
    key_file = "${path.module}/keys/${lookup(var.provisioner,"key_name")}.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${lookup(var.provisioner,"directory")}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${aws_spot_instance_request.dcos_bootstrap.private_dns} > ${lookup(var.provisioner,"directory")}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export DATACENTER=${var.infra_name} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export NODE_NAME=dcos_slave_public_node-${count.index} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${lookup(var.provisioner,"directory")}/vars",
      "echo export DCOS_NODE_TYPE=slave_public >> ${lookup(var.provisioner,"directory")}/vars"
    ]
  }
  provisioner "file" {
    source = "${path.module}/provision/"
    destination = "${lookup(var.provisioner,"directory")}"
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${lookup(var.provisioner,"directory")} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${lookup(var.provisioner,"directory")} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}

output "bootstrap_ip" {
  value = "${aws_spot_instance_request.dcos_bootstrap.public_ip}"
}

output "exhibitor_address" {
  value = "http://${aws_spot_instance_request.dcos_master_node.0.public_ip}:8181/exhibitor/v1/ui/index.html"
}

output "dcos_ui_address" {
  value = "http://${aws_spot_instance_request.dcos_master_node.0.public_ip}"
}

output "dcos_marathon_address" {
  value = "http://${aws_spot_instance_request.dcos_master_node.0.public_ip}:8080"
}

output "slave ip addresses" {
  value = "${join(",", aws_spot_instance_request.dcos_slave_node.*.public_ip)}"
}

output "slave_public ip addresses" {
  value = "${join(",", aws_spot_instance_request.dcos_slave_public_node.*.public_ip)}"
}

output "master ip addresses" {
  value = "${join(",", aws_spot_instance_request.dcos_master_node.*.public_ip)}"
}
