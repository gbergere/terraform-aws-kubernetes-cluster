###
# Bootstrap Script
##
data "template_file" "bootstrap_master" {
  template = "${file("${path.module}/bootstrap_master.sh")}"

  vars {
    cluster_name                = "${var.cluster_name}"
    version                     = "${var.version}"
    master_register_schedulable = "${var.master_register_schedulable}"
    service_node_port_range     = "${var.service_node_port_range}"
    etcd_url                    = "https://${aws_route53_record.etcd.fqdn}:2379"
    ca_pem                      = "${tls_self_signed_cert.ca.cert_pem}"
    cert_pem                    = "${tls_locally_signed_cert.kubernetes.cert_pem}"
    key_pem                     = "${tls_private_key.kubernetes.private_key_pem}"
  }
}

###
# Instances
##
resource "aws_instance" "master" {
  instance_type        = "${var.master_instance_type}"
  ami                  = "${data.aws_ami.core.id}"
  subnet_id            = "${aws_subnet.private.id}"
  key_name             = "${var.keypair}"
  iam_instance_profile = "${aws_iam_instance_profile.master.name}"

  root_block_device {
    volume_size           = "${var.master_disk_size}"
    delete_on_termination = true
  }

  user_data = "${data.template_file.bootstrap_master.rendered}"

  vpc_security_group_ids = [
    "${aws_security_group.ec2.id}",
    "${var.additional_security_groups}",
  ]

  tags {
    Name              = "${var.cluster_name}-master"
    KubernetesCluster = "${var.cluster_name}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_private_key" "kubernetes" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "kubernetes" {
  key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"

  dns_names    = ["api.${var.cluster_name}.${var.cluster_dns}"]
  ip_addresses = ["10.0.0.1"]

  subject {
    country             = "UK"
    common_name         = "kubernetes"
    organization        = "Kubernetes"
    organizational_unit = "${var.cluster_name}"
  }
}

resource "tls_locally_signed_cert" "kubernetes" {
  cert_request_pem   = "${tls_cert_request.kubernetes.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  # Certificate expires after 10 years.
  validity_period_hours = 87600

  # Generate a new certificate if Terraform is run within one
  # year of the certificate's expiration time.
  early_renewal_hours = 8760

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = ["client_auth", "server_auth"]
}
