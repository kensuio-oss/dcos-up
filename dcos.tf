variable "infra_name" {
  default = "test_infra"
}

variable "region" {
  default = "eu-west-1"
}

variable "availability_zone" {
  default = "b"
}

variable "bootstrap_port" {
  default = "10000"
}

variable "ami_ids" {
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
  default = {
    bootstrap    = "m4.2xlarge"
    master       = "m4.2xlarge"
    slave        = "m4.2xlarge"
    slave_public = "m4.2xlarge"
  }  
}

variable "instance_counts" {
  default = {
    master       = 1
    slave        = 2
    slave_public = 1
  }
}

variable "provisioner" {
  default = {
    username = "centos"
    key_name = "dcos-centos"
    keys_dir = "/Users/rad/Downloads"
    directory = "/home/centos/provisioner" # we need to survive reboots
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

resource "aws_instance" "dcos_bootstrap" {
  ami = "${lookup(var.ami_ids, var.region)}"
  instance_type = "${var.instance_types.bootstrap}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${var.provisioner.key_name}"
  tags {
    Name = "${var.infra_name}_dcos_bootstrap"
  }
  #security_groups = [ "${aws_security_group.ssh_access.name}",
  #                    "${aws_security_group.consul_member.name}",
  #                    "${aws_security_group.bootstrap_http.name}"]
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.bootstrap_http.id}"]
  connection {
    user = "${var.provisioner.username}"
    key_file = "${path.module}/keys//${var.provisioner.key_name}.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.provisioner.directory}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${self.private_dns} > ${var.provisioner.directory}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${var.provisioner.directory}/vars",
      "echo export EXPECTED_MASTER_COUNT=${var.instance_counts.master} >> ${var.provisioner.directory}/vars",
      "echo export EXPECTED_AGENT_COUNT=${var.instance_counts.slave+var.instance_counts.slave_public} >> ${var.provisioner.directory}/vars",
      "echo export DATACENTER=${var.infra_name} >> ${var.provisioner.directory}/vars",
      "echo export NODE_NAME=dcos_bootstrap >> ${var.provisioner.directory}/vars",
      "echo export IS_CONSUL_SERVER=true >> ${var.provisioner.directory}/vars",
      "echo export IS_BOOTSTRAP_SERVER=true >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${var.provisioner.directory}/vars"
    ]
  }
  provisioner "file" {
    source = "${path.module}/provision/"
    destination = "${var.provisioner.directory}"
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner.directory} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner.directory} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}

resource "aws_instance" "dcos_master_node" {
  count = "${var.instance_counts.master}"
  ami = "${lookup(var.ami_ids, var.region)}"
  instance_type = "${var.instance_types.master}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${var.provisioner.key_name}"
  tags {
    Name = "${var.infra_name}_dcos_master_node-${count.index}"
  }
  #security_groups = [ "${aws_security_group.ssh_access.name}",
  #                    "${aws_security_group.consul_member.name}",
  #                    "${aws_security_group.dcos_member.name}",
  #                     "${aws_security_group.dcos_master_insecure.name}" ]
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.dcos_member.id}",
                             "${aws_security_group.dcos_master_insecure.id}" ]
  connection {
    user = "${var.provisioner.username}"
    key_file = "${path.module}/keys//${var.provisioner.key_name}.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.provisioner.directory}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${aws_instance.dcos_bootstrap.private_dns} > ${var.provisioner.directory}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${var.provisioner.directory}/vars",
      "echo export DATACENTER=${var.infra_name} >> ${var.provisioner.directory}/vars",
      "echo export NODE_NAME=dcos_master_node-${count.index} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${var.provisioner.directory}/vars",
      "echo export DCOS_NODE_TYPE=master >> ${var.provisioner.directory}/vars"
    ]
  }
  provisioner "file" {
    source = "${path.module}/provision/"
    destination = "${var.provisioner.directory}"
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner.directory} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner.directory} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}

resource "aws_instance" "dcos_slave_node" {
  count = "${var.instance_counts.slave}"
  ami = "${lookup(var.ami_ids, var.region)}"
  instance_type = "${var.instance_types.slave}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${var.provisioner.key_name}"
  tags {
    Name = "${var.infra_name}_dcos_slave_node-${count.index}"
  }
  #security_groups = [ "${aws_security_group.ssh_access.name}",
  #                    "${aws_security_group.consul_member.name}",
  #                    "${aws_security_group.dcos_member.name}",
  #                    "${aws_security_group.dcos_slave.name}" ]
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.dcos_member.id}",
                             "${aws_security_group.dcos_slave.id}" ]
  connection {
    user = "${var.provisioner.username}"
    key_file = "${path.module}/keys/${var.provisioner.key_name}.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.provisioner.directory}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${aws_instance.dcos_bootstrap.private_dns} > ${var.provisioner.directory}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${var.provisioner.directory}/vars",
      "echo export DATACENTER=${var.infra_name} >> ${var.provisioner.directory}/vars",
      "echo export NODE_NAME=dcos_slave_node-${count.index} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${var.provisioner.directory}/vars",
      "echo export DCOS_NODE_TYPE=slave >> ${var.provisioner.directory}/vars"
    ]
  }
  provisioner "file" {
    source = "${path.module}/provision/"
    destination = "${var.provisioner.directory}"
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner.directory} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner.directory} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}

resource "aws_instance" "dcos_slave_public_node" {
  count = "${var.instance_counts.slave_public}"
  ami = "${lookup(var.ami_ids, var.region)}"
  instance_type = "${var.instance_types.slave_public}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${var.provisioner.key_name}"
  tags {
    Name = "${var.infra_name}_dcos_slave_public_node-${count.index}"
  }
  #security_groups = [ "${aws_security_group.ssh_access.name}",
  #                    "${aws_security_group.consul_member.name}",
  #                    "${aws_security_group.dcos_member.name}",
  #                    "${aws_security_group.dcos_slave_public.name}" ]
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.dcos_member.id}",
                             "${aws_security_group.dcos_slave_public.id}" ]
  connection {
    user = "${var.provisioner.username}"
    key_file = "${path.module}/keys/${var.provisioner.key_name}.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.provisioner.directory}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${aws_instance.dcos_bootstrap.private_dns} > ${var.provisioner.directory}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${var.provisioner.directory}/vars",
      "echo export DATACENTER=${var.infra_name} >> ${var.provisioner.directory}/vars",
      "echo export NODE_NAME=dcos_slave_public_node-${count.index} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${var.provisioner.directory}/vars",
      "echo export DCOS_NODE_TYPE=slave_public >> ${var.provisioner.directory}/vars"
    ]
  }
  provisioner "file" {
    source = "${path.module}/provision/"
    destination = "${var.provisioner.directory}"
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner.directory} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner.directory} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}

output "bootstrap_ip" {
  value = "${aws_instance.dcos_bootstrap.public_ip}"
}

output "exhibitor_address" {
  value = "http://${aws_instance.dcos_master_node.public_ip}:8181/exhibitor/v1/ui/index.html"
}

output "dcos_ui_address" {
  value = "http://${aws_instance.dcos_master_node.public_ip}"
}

output "dcos_marathon_address" {
  value = "http://${aws_instance.dcos_master_node.public_ip}:8080"
}
