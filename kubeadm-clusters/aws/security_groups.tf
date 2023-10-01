###############################################################
#
# This file contains configuration for all security groups
# we will need.
#
###############################################################

# Security group for egress to anywhere.
# Will be applied to all EC2 instances
resource "aws_security_group" "egress_all" {
  name   = "egress_all"
  vpc_id = data.aws_vpc.default_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_vpc" {
  name   = "ingress_vpc"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default_vpc.cidr_block]
  }
}

# Security group for ingress to controlplane
resource "aws_security_group" "controlplane" {
  name   = "controlplane"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    # Allow SSH from cloudshell
    description = "Login SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "${chomp(data.http.cloudshell_ip.response_body)}/32"
    ]
  }

  ingress {
    # Allow API server access from anywhere inside the VPC
    description = "API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [
      data.aws_vpc.default_vpc.cidr_block
    ]
  }

  ingress {
    # Allow etcd access from anywhere inside the VPC
    description = "etcd"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [
      data.aws_vpc.default_vpc.cidr_block
    ]
  }
}

# Security group for ingress to worker nodes
resource "aws_security_group" "workernode" {
  name   = "workernode"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    # Allow SSH from any host that has student_node security group
    description = "Login SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "${chomp(data.http.cloudshell_ip.response_body)}/32"
      ]
  }

  ingress {
    # Allow SSH from any host that has controlplane security group
    description = "kubelet api"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    security_groups = [
      aws_security_group.controlplane.id
    ]
  }

  ingress {
    # Allow access to node ports cloudshell
    # and student node
    description = "Node Ports"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [
      "${chomp(data.http.cloudshell_ip.response_body)}/32"
      ]
    security_groups = [
      aws_security_group.student_node.id
    ]
  }
}

# Security group for communication between weave pods
resource "aws_security_group" "weave" {
  name   = "weave"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    description = "Weave TCP"
    from_port   = 6783
    to_port     = 6783
    protocol    = "tcp"
    security_groups = [
      aws_security_group.controlplane.id,
      aws_security_group.workernode.id
    ]
  }

  ingress {
    description = "Weave UDP"
    from_port   = 6783
    to_port     = 6784
    protocol    = "udp"
    security_groups = [
      aws_security_group.controlplane.id,
      aws_security_group.workernode.id
    ]
  }
}

