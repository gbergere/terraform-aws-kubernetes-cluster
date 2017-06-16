output "security_group" {
  value = "${aws_security_group.ec2.id}"
}

output "private_subnet" {
  value = "${aws_subnet.private.cidr_block}"
}

output "master" {
  value = "${aws_instance.master.private_ip}"
}
