variable "infra_name" {
  default = "3dr_dcos_infra"
}

variable "region" {
  default = "us-east-1"
}

variable "availability_zone" {
  default = "b"
}

variable "bootstrap_port" {
  default = "10000"
}
# coreos ami is used only for us-east-1 and us-west-1
variable "ami_ids" {
  default {
    us-east-1 = "ami-1c94e10b"
    us-west-1 = "ami-43561a23"
  }
}

variable "instance_types" {
  default = {
    bootstrap    = "m3.xlarge"
    master       = "m3.xlarge"
    agent        = "m3.xlarge"
    agent_public = "m3.xlarge"
  }  
}

variable "instance_counts" {
  default = {
    master       = 1
    agent        = 2
    agent_public = 1
  }
}
#variable "vpc_cidr"{
#  description = "CIDR for dcos"
#  default = "10.0.0.0/16"
#}

#variable "private_subnet_cidr" {
#  description = "DCOS CIDR for the Private Subnet"
#  default = "10.0.0.0/22"
#}

#variable "public_subnet_cidr" {
#  description = "DCOS CIDR for the Public Subnet"
#  default = "10.0.4.0/22"
#}

# please change the keys_dir that reflect the dcos_key dir on your machine
variable "provisioner" {
  default = {
    username = "core"
    key_name = "dcos-key"
    keys_dir = "/Users/ant/.ssh/"
    directory = "/home/core/provisioner" # we need to survive reboots
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

resource "aws_security_group" "dcos_agent" {
  name = "${var.infra_name}_dcos_agent"
  description = "DCOS agent access"
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

resource "aws_security_group" "dcos_agent_public" {
  name = "${var.infra_name}_dcos_agent_public"
  description = "DCOS agent public access"
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
      "echo export EXPECTED_AGENT_COUNT=${var.instance_counts.agent+var.instance_counts.agent_public} >> ${var.provisioner.directory}/vars",
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

resource "aws_instance" "dcos_agent_node" {
  count = "${var.instance_counts.agent}"
  ami = "${lookup(var.ami_ids, var.region)}"
  instance_type = "${var.instance_types.agent}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${var.provisioner.key_name}"
  tags {
    Name = "${var.infra_name}_dcos_agent_node-${count.index}"
  }
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.dcos_member.id}",
                             "${aws_security_group.dcos_agent.id}" ]
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
      "echo export NODE_NAME=dcos_agent_node-${count.index} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${var.provisioner.directory}/vars",
      "echo export DCOS_NODE_TYPE=agent >> ${var.provisioner.directory}/vars"
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

resource "aws_instance" "dcos_agent_public_node" {
  count = "${var.instance_counts.agent_public}"
  ami = "${lookup(var.ami_ids, var.region)}"
  instance_type = "${var.instance_types.agent_public}"
  availability_zone = "${var.region}${var.availability_zone}"
  key_name = "${var.provisioner.key_name}"
  tags {
    Name = "${var.infra_name}_dcos_agent_public_node-${count.index}"
  }
  vpc_security_group_ids = [ "${aws_security_group.ssh_access.id}",
                             "${aws_security_group.consul_member.id}",
                             "${aws_security_group.dcos_member.id}",
                             "${aws_security_group.dcos_agent_public.id}" ]
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
      "echo export NODE_NAME=dcos_agent_public_node-${count.index} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${var.provisioner.directory}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${var.provisioner.directory}/vars",
      "echo export DCOS_NODE_TYPE=agent_public >> ${var.provisioner.directory}/vars"
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
