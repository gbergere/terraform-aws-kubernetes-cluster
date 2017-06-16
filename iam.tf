resource "aws_iam_instance_profile" "master" {
  name = "${var.cluster_name}-master"
  role = "${aws_iam_role.master.name}"
}

resource "aws_iam_instance_profile" "nodes" {
  name = "${var.cluster_name}-nodes"
  role = "${aws_iam_role.nodes.name}"
}

resource "aws_iam_role" "master" {
  name               = "${var.cluster_name}-master"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ec2.json}"
}

resource "aws_iam_role" "nodes" {
  name               = "${var.cluster_name}-nodes"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ec2.json}"
}

data "aws_iam_policy_document" "ec2" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_policy" "master" {
  name   = "${var.cluster_name}-master"
  policy = "${data.aws_iam_policy_document.master.json}"
}

resource "aws_iam_policy" "nodes" {
  name   = "${var.cluster_name}-nodes"
  policy = "${data.aws_iam_policy_document.nodes.json}"
}

data "aws_iam_policy_document" "master" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:*",
      "ecr:*",
      "elasticloadbalancing:*",
      "route53:*",
    ]

    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy_document" "nodes" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:Describe*",
      "ec2:ModifyInstanceAttribute",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy_attachment" "master" {
  name       = "${var.cluster_name}-master"
  roles      = ["${aws_iam_role.master.name}"]
  policy_arn = "${aws_iam_policy.master.arn}"
}

resource "aws_iam_policy_attachment" "nodes" {
  name       = "${var.cluster_name}-nodes"
  roles      = ["${aws_iam_role.nodes.name}"]
  policy_arn = "${aws_iam_policy.nodes.arn}"
}
