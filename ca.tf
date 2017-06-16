resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = "${tls_private_key.ca.algorithm}"
  private_key_pem = "${tls_private_key.ca.private_key_pem}"

  # Certificate expires after 10 years.
  validity_period_hours = 87600

  # Generate a new certificate if Terraform is run within one
  # year of the certificate's expiration time.
  early_renewal_hours = 8760

  # Reasonable set of uses for a server SSL certificate.
  is_ca_certificate = true
  allowed_uses      = ["cert_signing", "key_ encipherment", "server_auth", "client_auth"]

  subject {
    country             = "UK"
    common_name         = "Kubernetes"
    organization        = "Kubernetes"
    organizational_unit = "${var.cluster_name}"
  }

  provisioner "local-exec" {
    command = "echo '${tls_self_signed_cert.ca.cert_pem}' > ${path.cwd}/ssl/ca.pem && kubectl config set-cluster ${var.cluster_name} --embed-certs=true --certificate-authority=${path.cwd}/ssl/ca.pem --server=https://api.${var.cluster_name}.${var.cluster_dns}:6443 --kubeconfig=${pathexpand("~/.kube/config")}"
  }
}
