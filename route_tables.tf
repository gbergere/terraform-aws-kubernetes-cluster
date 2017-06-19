resource "aws_route_table" "private" {
  vpc_id           = "${var.vpc_id}"
  propagating_vgws = ["${var.propagating_vgws}"]

  tags {
    Name              = "Kubernetes ${var.cluster_name} Private RT"
    KubernetesCluster = "${var.cluster_name}"
  }
}

resource "aws_route" "default" {
  route_table_id         = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${var.nat_internet_gateway}"
}
