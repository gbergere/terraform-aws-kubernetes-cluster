###
# Bootstrap Script
##
data "template_file" "bootstrap_nodes" {
  template = "${file("${path.module}/bootstrap_nodes.sh")}"

  vars {
    cluster_name        = "${var.cluster_name}"
    version             = "${var.version}"
    api_url             = "https://api.${var.cluster_name}.${var.cluster_dns}:6443"
    ca_pem              = "${tls_self_signed_cert.ca.cert_pem}"
    ca_key_pem          = "${tls_private_key.ca.private_key_pem}"
    kube_proxy_cert_pem = "${tls_locally_signed_cert.kube_proxy.cert_pem}"
    kube_proxy_key_pem  = "${tls_private_key.kube_proxy.private_key_pem}"
  }
}

###
# AutoScaling Group + Launch Configuration
##
resource "aws_launch_configuration" "nodes" {
  name_prefix = "${var.cluster_name}-nodes-"

  image_id             = "${data.aws_ami.core.id}"
  instance_type        = "${var.nodes_instance_type}"
  key_name             = "${var.keypair}"
  iam_instance_profile = "${aws_iam_instance_profile.nodes.name}"

  security_groups = [
    "${aws_security_group.ec2.id}",
    "${var.additional_security_groups}",
  ]

  root_block_device {
    volume_size           = "${var.nodes_disk_size}"
    delete_on_termination = true
  }

  user_data = "${data.template_file.bootstrap_nodes.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nodes" {
  depends_on = ["aws_instance.master"]

  name                 = "${var.cluster_name}-nodes"
  termination_policies = ["OldestLaunchConfiguration", "OldestInstance"]
  vpc_zone_identifier  = ["${aws_subnet.private.id}"]

  min_size = "${var.min_nodes_count}"
  max_size = "${var.max_nodes_count}"

  launch_configuration = "${aws_launch_configuration.nodes.name}"
  suspended_processes  = ["AZRebalance"]                          # Would mess up with cluster-autoscaler

  tag {
    key                 = "KubernetesCluster"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-node"
    propagate_at_launch = true
  }
}

resource "tls_private_key" "kube_proxy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "kube_proxy" {
  key_algorithm   = "${tls_private_key.kube_proxy.algorithm}"
  private_key_pem = "${tls_private_key.kube_proxy.private_key_pem}"

  subject {
    country             = "UK"
    common_name         = "system:kube-proxy"
    organization        = "system:node-proxier"
    organizational_unit = "${var.cluster_name}"
  }
}

resource "tls_locally_signed_cert" "kube_proxy" {
  cert_request_pem   = "${tls_cert_request.kube_proxy.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  # Certificate expires after 10 years.
  validity_period_hours = 87600

  # Generate a new certificate if Terraform is run within one
  # year of the certificate's expiration time.
  early_renewal_hours = 8760

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = ["client_auth"]
}

resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = "echo '${tls_private_key.admin.private_key_pem}' > ${path.cwd}/ssl/key.pem"
  }
}
