/*
  Security Groups for DC/OS VPC
*/


resource "aws_security_group" "default" {
  name = default
  description = "default VPC security group"
 
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      self = true
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_block = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dcos-cluster-AdminSecurityGroup"{
  name = "dcos-cluster-AdminSecurityGroup"
  description = "Enable Admin access to servers"
  
  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }  
  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }  
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }  
  egress  {
      from_port = 0
      to_port = 0
      protocol = "ALL"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dcos-cluster-PublicSlaveSecurityGroup"{
  name = "dcos-cluster-PublicSlaveSecurityGroup"
  description = "Mesos Slaves Public"
  
  ingress {
      from_port = 0 
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
  ingress {
      from_port = 0
      to_port = 21
      protocol = "udp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port = 23
      to_port = 5050
      protocol = "udp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port = 5052
      to_port = 32000
      protocol = "udp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port = 0 
      to_port = 0
      protocol = "-1"
      self = true
  }
  ingress {
      from_port = 0 
      to_port = 0
      protocol = "-1"
      security_groups = ["${aws_security_group.dcos-cluster-SlaveSecurityGroup}"]
  }
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      security_groups = ["${aws_security_group.dcos-cluster-MasterSecurityGroup}"]
  }
  
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dcos-cluster-MasterSecurityGroup" {
  name = dcos-cluster-MasterSecurityGroup
  description = Mesos Masters
 
  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      security_groups = ["${aws_security_group.dcos-cluster-LbSecurityGroup}"]
  }
  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      security_groups = ["${aws_security_group.dcos-cluster-LbSecurityGroup}"]
  }
  ingress {
      from_port = 2181
      to_port = 2181
      protocol = "tcp"
      security_groups = ["${aws_security_group.dcos-cluster-LbSecurityGroup}"]
  }
  ingress {
      from_port = 5050
      to_port = 5050
      protocol = "tcp"
      security_groups = ["${aws_security_group.dcos-cluster-LbSecurityGroup}"]
  }
  ingress {
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      security_groups = ["${aws_security_group.dcos-cluster-LbSecurityGroup}"]
  }
  ingress {
      from_port = 8181
      to_port = 8181
      protocol = "tcp"
      security_groups = ["${aws_security_group.dcos-cluster-LbSecurityGroup}"]
  }
  ingress {
      from_port = 0 
      to_port = 0
      protocol = "-1"
      security_groups = ["${aws_security_group.dcos-cluster-PublicSlaveSecurityGroup}"]
  }
  ingress {
      from_port = 0
      to_port = 0
      protocol = -1
      security_groups = ["${aws_security_group.dcos-cluster-SlaveSecurityGroup}"]
  }
  ingress {
      from_port = 0
      to_port = 0
      protocol = -1
      self = true
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = -1
      cidr_blocks = ["0.0.0.0/0"]
  }
 }

resource "aws_security_group" "dcos-cluster-SlaveSecurityGroup" {
  name = dcos-cluster-SlaveSecurityGroup
  description = Mesos Slaves

  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      security_groups = ["${aws_security_group.dcos-cluster-PublicSlaveSecurityGroup}"]
  }
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      self = true
  }
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      security_groups = ["${aws_security_group.dcos-cluster-MasterSecurityGroup}"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dcos-cluster-LbSecurityGroup" {
  name = dcos-cluster-LbSecurityGroup
  description = Mesos Master LB

  ingress {
      from_port = 2181
      to_port = 2181
      protocol = "tcp"
      security_groups = ["${aws_security_group.dcos-cluster-SlaveSecurityGroup}"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
 }

}
