data "aws_route53_zone" "primary" {
  name = "${var.cluster_dns}."
}

resource "aws_route53_record" "etcd" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "etcd.${var.cluster_name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.etcd.private_ip}"]
}

resource "aws_route53_record" "api" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "api.${var.cluster_name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.master.private_ip}"]
}
