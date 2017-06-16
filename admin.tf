resource "tls_cert_request" "admin" {
  key_algorithm   = "${tls_private_key.admin.algorithm}"
  private_key_pem = "${tls_private_key.admin.private_key_pem}"

  subject {
    country             = "UK"
    common_name         = "admin"               # Used as username for Auth to the cluster
    organization        = "system:masters"
    organizational_unit = "${var.cluster_name}"
  }
}

resource "tls_locally_signed_cert" "admin" {
  cert_request_pem   = "${tls_cert_request.admin.cert_request_pem}"
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

  provisioner "local-exec" {
    command = "echo '${tls_locally_signed_cert.admin.cert_pem}' > ${path.cwd}/ssl/cert.pem && kubectl config set-credentials ${var.cluster_name} --embed-certs=true --client-certificate=${path.cwd}/ssl/cert.pem --client-key=${path.cwd}/ssl/key.pem --kubeconfig=${pathexpand("~/.kube/config")} && kubectl config set-context ${replace(var.cluster_name, "k8s-", "")} --cluster=${var.cluster_name} --user=${var.cluster_name} --kubeconfig=${pathexpand("~/.kube/config")}"
  }
}
