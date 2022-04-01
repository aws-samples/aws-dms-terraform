data "aws_iam_policy_document" "ssm" {
  statement {
    sid =   "1"
    effect = "Allow"
    actions = [
        "ssm:DescribeAssociation",
        "ssm:GetDeployablePatchSnapshotForInstance",
        "ssm:GetDocument",
        "ssm:DescribeDocument",
        "ssm:GetManifest",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:ListAssociations",
        "ssm:ListInstanceAssociations",
        "ssm:PutInventory",
        "ssm:PutComplianceItems",
        "ssm:PutConfigurePackageResult",
        "ssm:UpdateAssociationStatus",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:UpdateInstanceInformation"
    ]
    resources = ["*"]
  }

  statement {
    sid =   "2"
    effect = "Allow"
    actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }

  statement {
    sid =   "3"
    effect = "Allow"
    actions = [
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "sts" {
  statement {
    sid =   "1"
    effect = "Allow"
    principals  {
        type         = "Service"
        identifiers  = ["ec2.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "s3_gateway" {
  statement {
    sid =   "1"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
        "s3:GetObject"
    ]
    resources = ["arn:aws:s3:::amazonlinux.${var.region}.amazonaws.com/*",
                 "arn:aws:s3:::amazonlinux-2-repos-${var.region}/*"]
  }
}

data "aws_ami" "amazon_linux_2" {
 most_recent  = true
 owners       = ["amazon"]

 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }

 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }
}


data "aws_network_interface" "db" {
  # id = "eni-067d6bfbadc6d034d"
  filter {
    name = "group-id"
    values = [aws_security_group.db_sg.id]
    # values = ["sg-0652e6a207adfec6a"]
  }
  
  depends_on = [
    aws_security_group.db_sg,
    aws_db_instance.target_db
  ]

}

data "aws_network_interface" "db_2" {

  filter {
    name = "group-id"
    values = [aws_security_group.db_sg_2.id]
  }
  depends_on = [
    aws_security_group.db_sg_2,
    aws_db_instance.source_db
  ]
}
