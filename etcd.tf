data "template_file" "bootstrap_etcd" {
  template = "${file("${path.module}/bootstrap_etcd.yml")}"

  vars {
    ca_pem             = "${tls_self_signed_cert.ca.cert_pem}"
    cert_pem           = "${tls_locally_signed_cert.etcd.cert_pem}"
    key_pem            = "${tls_private_key.etcd.private_key_pem}"
    listen_client_urls = "https://etcd.${var.cluster_name}.${var.cluster_dns}:2379"
  }
}

resource "aws_instance" "etcd" {
  instance_type = "t2.micro"
  ami           = "${data.aws_ami.core.id}"
  subnet_id     = "${aws_subnet.private.id}"
  key_name      = "${var.keypair}"

  user_data = "${data.template_file.bootstrap_etcd.rendered}"

  vpc_security_group_ids = [
    "${aws_security_group.etcd.id}",
    "${var.additional_security_groups}",
  ]

  tags {
    Name              = "${var.cluster_name}-etcd"
    KubernetesCluster = "${var.cluster_name}"
  }

  lifecycle {
    ignore_changes = ["ami", "user_data"]
  }
}

resource "aws_security_group" "etcd" {
  name        = "${var.cluster_name}-etcd-ec2"
  description = "${var.cluster_name}-etcd security group EC2"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 2379
    to_port         = 2379
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ec2.id}"]
  }

  tags {
    Name              = "${var.cluster_name}-etcd-ec2"
    KubernetesCluster = "${var.cluster_name}"
  }
}

resource "tls_private_key" "etcd" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "etcd" {
  key_algorithm   = "${tls_private_key.etcd.algorithm}"
  private_key_pem = "${tls_private_key.etcd.private_key_pem}"

  dns_names = ["etcd.${var.cluster_name}.${var.cluster_dns}"]

  subject {
    country             = "UK"
    common_name         = "${var.cluster_dns}"
    organization        = "Kubernetes"
    organizational_unit = "${var.cluster_name}"
  }
}

resource "tls_locally_signed_cert" "etcd" {
  cert_request_pem   = "${tls_cert_request.etcd.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  # Certificate expires after 10 years.
  validity_period_hours = 87600

  # Generate a new certificate if Terraform is run within one
  # year of the certificate's expiration time.
  early_renewal_hours = 8760

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = ["server_auth"]
}
