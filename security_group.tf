###
# Security Group
##
resource "aws_security_group" "ec2" {
  name        = "${var.cluster_name}-ec2"
  description = "${var.cluster_name} security group EC2"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name              = "${var.cluster_name}-ec2"
    KubernetesCluster = "${var.cluster_name}"
  }

  # Allow ALL inbound traffic to itself
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow Kubernetes API inbound from VPN
  ingress {
    from_port = 6443
    to_port   = 6443
    protocol  = "tcp"

    cidr_blocks = ["${var.whitelisted_ips}"]
  }

  # Allow Kubernetes Services to be exposed (--server-node-port-range)
  ingress {
    from_port = "${element(split("-", var.service_node_port_range), 0)}"
    to_port   = "${element(split("-", var.service_node_port_range), 1)}"
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow ALL outbound traffic to itself
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow ALL outbound traffic anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes        = ["description"]
    create_before_destroy = true
  }
}
