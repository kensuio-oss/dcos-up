/*
  Security Groups for DC/OS VPC
*/

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
      security_groups = ["${aws_security_group.}"]
  }
  ingress {
      from_port = 
      to_port = 
      protocol = ""
      security_groups =
  }
  ingress {
      from_port = 
      to_port = 
      protocol = ""
      security_group_id =
  }
  
  
}
