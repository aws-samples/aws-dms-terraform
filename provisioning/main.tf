provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

########################################################## On-premise VPC for Source DB
module "source_db_vpc" {
  source                = "terraform-aws-modules/vpc/aws"
  name                  = var.vpc_name
  cidr                  = var.vpc_cidr
  azs                   = var.vpc_azs
  private_subnets       = var.vpc_private_subnets
  public_subnets        = var.vpc_public_subnets
  tags                  = var.common_tags
  enable_dns_hostnames  = true
  enable_dns_support    = true
}

########################################################## DMS VPC

module "dms_vpc" {
  source                = "terraform-aws-modules/vpc/aws"
  name                  = var.vpc2_name
  cidr                  = var.vpc2_cidr
  azs                   = var.vpc2_azs
  private_subnets       = var.vpc2_private_subnets
  tags                  = var.common_tags
  enable_dns_hostnames  = true
  enable_dns_support    = true
}

########################################################## Target DB VPC
module "target_db_vpc" {
  source                = "terraform-aws-modules/vpc/aws"
  name                  = var.vpc3_name
  cidr                  = var.vpc3_cidr
  azs                   = var.vpc3_azs
  private_subnets       = var.vpc3_private_subnets
  tags                  = var.common_tags
  enable_dns_hostnames  = true
  enable_dns_support    = true
}

#-${random_string.random.id}"
#################################################### DMS
resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  replication_subnet_group_description = "dms subnet group"  
  replication_subnet_group_id          = "dms-subnet-group"  

  subnet_ids = module.dms_vpc.private_subnets

}

resource "aws_security_group" "dms_sec_group" {
  name_prefix     = "dms_sg"
  vpc_id          = module.dms_vpc.vpc_id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [module.source_db_vpc.vpc_cidr_block]
  }
  egress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [module.dms_vpc.vpc_cidr_block]
  }
}

resource "aws_iam_role" "dms-access-for-endpoint" {
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  name               = "dms-access-for-endpoint"
}

resource "aws_iam_role_policy_attachment" "dms-access-for-endpoint-AmazonDMSRedshiftS3Role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSRedshiftS3Role"
  role       = aws_iam_role.dms-access-for-endpoint.name
}

resource "aws_iam_role" "dms-cloudwatch-logs-role" {
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  name               = "dms-cloudwatch-logs-role"
}

resource "aws_iam_role_policy_attachment" "dms-cloudwatch-logs-role-AmazonDMSCloudWatchLogsRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  role       = aws_iam_role.dms-cloudwatch-logs-role.name
}

resource "aws_iam_role" "dms-vpc-role" {
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  name               = "dms-vpc-role"
}

resource "aws_iam_role_policy_attachment" "dms-vpc-role-AmazonDMSVPCManagementRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = aws_iam_role.dms-vpc-role.name
}

resource "aws_dms_replication_instance" "test" {
  allocated_storage            = 20
  apply_immediately            = true
  auto_minor_version_upgrade   = false
  availability_zone            = "us-east-1a"
  publicly_accessible          = false
  replication_instance_class   = "dms.t2.micro"
  replication_instance_id      = "dms-instance"
  replication_subnet_group_id  = aws_dms_replication_subnet_group.dms_subnet_group.id

  vpc_security_group_ids = [aws_security_group.dms_sec_group.id]

  depends_on = [
    aws_iam_role_policy_attachment.dms-access-for-endpoint-AmazonDMSRedshiftS3Role,
    aws_iam_role_policy_attachment.dms-cloudwatch-logs-role-AmazonDMSCloudWatchLogsRole,
    aws_iam_role_policy_attachment.dms-vpc-role-AmazonDMSVPCManagementRole
  ]
}

locals {
  target_endpoint = aws_vpc_endpoint.target_endpoint.dns_entry[0]["dns_name"]
  source_endpoint = aws_vpc_endpoint.source_endpoint.dns_entry[0]["dns_name"]
  db_creds_source = jsondecode(aws_secretsmanager_secret_version.source_db_secret.secret_string)
  db_creds_target = jsondecode(aws_secretsmanager_secret_version.target_db_secret.secret_string)
}

resource "aws_dms_endpoint" "target" {
  endpoint_id                 = "target-db" 
  endpoint_type               = "target"
  engine_name                 = "postgres"
  database_name               = "demo_db"
  server_name                 = local.target_endpoint
  # username                    = aws_db_instance.target_db.username     #postgresql
  username                    = module.cluster_target_db.cluster_master_username   #aurora-postgresql
  password                    = local.db_creds_target.password
  port                        = 5432
}

resource "aws_dms_endpoint" "source" {
  endpoint_id                 = "source-db" 
  endpoint_type               = "source"
  engine_name                 = "postgres"
  database_name               = "demo_db"
  server_name                 = local.source_endpoint
  # username                    = aws_db_instance.source_db.username                #postgresql
  username                    = module.cluster_source_db.cluster_master_username    #aurora-postgresql
  password                    = local.db_creds_source.password
  port                        = 5432
}

resource "aws_vpc_endpoint" "dms-endpoint" {
  vpc_id              = module.dms_vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.dms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.dms_vpc.private_subnets
  security_group_ids  = [aws_security_group.dms_sec_grp.id]
  private_dns_enabled = true
  
  tags = merge(var.common_tags,
    {
      Name        = "DMS-EP"
    }
  )
}

resource "aws_security_group" "dms_sec_grp" {
  name_prefix     = "dms-ep-sg"
  vpc_id          = module.dms_vpc.vpc_id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [module.dms_vpc.vpc_cidr_block]
  }

  tags = merge(var.common_tags,
    {
        Name        = "dms-ep-sg"
    }
  )
}

########################################### NLB in target VPC
resource "aws_lb" "nlb_target_vpc" {
  name                             = "${var.nlb_name}-target"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = module.target_db_vpc.private_subnets

  tags = merge(var.common_tags,
    {
      Name        = "${var.nlb_name}-target"
    }
  )
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb_target_vpc.arn
  port              = "5432"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_target_group.arn
  }
}

resource "aws_lb_target_group" "nlb_target_group" {
  name          =  "${var.nlb_tg_name}-target"
  port          = 5432
  protocol      = "TCP"
  vpc_id        = module.target_db_vpc.vpc_id
  target_type   = "ip"
}


resource "aws_lb_target_group_attachment" "target_db" {
  target_group_arn = aws_lb_target_group.nlb_target_group.arn
  # target_id        = data.aws_network_interface.target_db.private_ip
  target_id        = data.aws_network_interface.cluster_target_db.private_ip
  port             = 5432
}

########################################### NLB in Source VPC
resource "aws_lb" "nlb_source_vpc" {
  name                        = "${var.nlb_name}-source"
  internal                    = true
  load_balancer_type          = "network"
  subnets                     = module.source_db_vpc.private_subnets
  
  tags = merge(var.common_tags,
    {
      Name        = "${var.nlb_name}-source"
    }
  )
}

resource "aws_lb_listener" "nlb_listener_2" {
  load_balancer_arn = aws_lb.nlb_source_vpc.arn
  port              = "5432"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_target_group_2.arn
  }
}

resource "aws_lb_target_group" "nlb_target_group_2" {
  name          = "${var.nlb_tg_name}-source"
  port          = 5432
  protocol      = "TCP"
  vpc_id        = module.source_db_vpc.vpc_id
  target_type   = "ip"
}


resource "aws_lb_target_group_attachment" "source_db" {
  target_group_arn = aws_lb_target_group.nlb_target_group_2.arn
  # target_id        = data.aws_network_interface.source_db.private_ip
  target_id        = data.aws_network_interface.cluster_source_db.private_ip
  port             = 5432
}

resource "aws_iam_role" "instance" {
  name_prefix         = "InstProfileForEC2-"
  assume_role_policy  = data.aws_iam_policy_document.sts.json
  inline_policy {
    name   = "ssm-policy"
    policy = data.aws_iam_policy_document.ssm.json
  }
  inline_policy {
    name   = "dms-policy"
    policy = data.aws_iam_policy_document.dms.json
  }
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name_prefix = "ec2_instance_profile_"
  role        = aws_iam_role.instance.name
}

########################################################### Privatelink 

resource "aws_vpc_endpoint_service" "endpoint_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb_target_vpc.arn]
  tags = merge(var.common_tags,
    {
      Name        = "${var.vpc_endpoint_service_name}-target"
    }
  )
}

resource "aws_security_group" "endpoint_sec_grp" {
  name_prefix     = var.endpoint_sg_name
  vpc_id          = module.dms_vpc.vpc_id

  ingress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [module.dms_vpc.vpc_cidr_block]
  }

  tags = merge(var.common_tags,
    {
        Name        = var.endpoint_sg_name
    }
  )
}

resource "aws_vpc_endpoint" "target_endpoint" {
  vpc_id              = module.dms_vpc.vpc_id
  service_name        = aws_vpc_endpoint_service.endpoint_service.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.dms_vpc.private_subnets
  security_group_ids  = [aws_security_group.endpoint_sec_grp.id]
  tags = merge(var.common_tags,
    {
      Name        = "${var.vpc_endpoint_name}-target"
    }
  )
}

############################################## Privatelink 2

resource "aws_vpc_endpoint_service" "endpoint_service_2" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.nlb_source_vpc.arn]
  tags = merge(var.common_tags,
    {
      Name        = "${var.vpc_endpoint_service_name}-src"
    }
  )
}

resource "aws_security_group" "endpoint_sec_grp_2" {
  name_prefix    = var.endpoint_sg_name
  vpc_id         = module.dms_vpc.vpc_id

  ingress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [module.dms_vpc.vpc_cidr_block]
  }

  tags = merge(var.common_tags,
    {
        Name        = var.endpoint_sg_name
    }
  )
}

resource "aws_vpc_endpoint" "source_endpoint" {
  vpc_id              = module.dms_vpc.vpc_id
  service_name        = aws_vpc_endpoint_service.endpoint_service_2.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.dms_vpc.private_subnets
  security_group_ids  = [aws_security_group.endpoint_sec_grp_2.id]
  tags = merge(var.common_tags,
    {
      Name        = "${var.vpc_endpoint_name}-src"
    }
  )
}

# resource "aws_db_subnet_group" "subnet_group" {
#   name_prefix   = "subnet-grp-"
#   subnet_ids    = module.target_db_vpc.private_subnets

#   tags = {
#     Name = "postgres-subnet-group"
#   }
# }

resource "aws_secretsmanager_secret" "masterdb_secret" {
   name_prefix = "target_db_"
}


resource "aws_secretsmanager_secret_version" "target_db_secret" {
  secret_id = aws_secretsmanager_secret.masterdb_secret.id
  secret_string = jsonencode({
    "username"             = "postgres"
    "password"             = "${random_string.target_db.id}"
  })
}



# resource "aws_db_instance" "target_db" {
#   identifier              = "target-db"
#   allocated_storage       = 20
#   engine                  = "postgres"
#   instance_class          = "db.t3.micro"
#   port                    = 5432
#   username                = local.db_creds_target.username
#   password                = local.db_creds_target.password
#   db_subnet_group_name    = aws_db_subnet_group.subnet_group.name
#   vpc_security_group_ids  = [aws_security_group.db_sg.id]
#   publicly_accessible     = false
#   apply_immediately       = true
#   skip_final_snapshot     = true
#   tags = merge(var.common_tags,
#     {
#       Name        = "postgres"
#     }
#   )
# }

# target db
module "cluster_target_db" {
  source  = "terraform-aws-modules/rds-aurora/aws"

  name              = "target-db-aurora-postgresql"
  engine            = "aurora-postgresql"
  engine_version    = "13.4"
  instance_class    = "db.t3.medium"
  instances = {
    one = {}
  }

  vpc_id                        = module.target_db_vpc.vpc_id
  subnets                       = module.target_db_vpc.private_subnets
  master_username               = local.db_creds_target.username
  master_password               = local.db_creds_target.password
  database_name                 = "postgres"
  create_random_password        = false
  apply_immediately             = true
  skip_final_snapshot           = true

  allowed_security_groups       = [aws_security_group.db_sg_target.id]
  allowed_cidr_blocks           = [module.target_db_vpc.vpc_cidr_block]

  storage_encrypted                     = true
  monitoring_interval                   = 10
  iam_database_authentication_enabled   = false
  auto_minor_version_upgrade            = false

  tags = merge(var.common_tags,
    {
      Name        = "target-db-aurora-postgresql"
    }
  )
}

### source db
module "cluster_source_db" {
  source            = "terraform-aws-modules/rds-aurora/aws"
  name              = "source-db-aurora-postgresql"
  engine            = "aurora-postgresql"
  engine_version    = "13.4"
  instance_class    = "db.t3.medium"
  instances = {
    one = {}
  }

  vpc_id                        = module.source_db_vpc.vpc_id
  subnets                       = module.source_db_vpc.private_subnets
  master_username               = local.db_creds_source.username
  master_password               = local.db_creds_source.password
  database_name                 = "postgres"
  create_random_password        = false
  apply_immediately             = true
  skip_final_snapshot           = true

  allowed_security_groups       = [aws_security_group.db_sg_source.id]
  allowed_cidr_blocks           = [module.source_db_vpc.vpc_cidr_block]

  storage_encrypted                     = true
  monitoring_interval                   = 10
  iam_database_authentication_enabled   = false
  auto_minor_version_upgrade            = false

  tags = merge(var.common_tags,
    {
      Name        = "source-db-aurora-postgresql"
    }
  )
}

resource "random_string" "source_db" {
  length       = 8
  special      = false
  lower        = true
  min_numeric  = 0
}

resource "random_string" "target_db" {
  length       = 8
  special      = false
  lower        = true
  min_numeric  = 0
}

# sg for target db
# resource "aws_security_group" "db_sg" {
#   name_prefix     = "db-SG-"
#   vpc_id          = module.target_db_vpc.vpc_id

#   ingress {
#     from_port        = 5432
#     to_port          = 5432
#     protocol         = "tcp"
#     cidr_blocks      = [module.target_db_vpc.vpc_cidr_block]
#   }
#   tags = merge(var.common_tags,
#     {
#       Name        = "db-SG"
#     }
#   )
# }

resource "aws_security_group" "db_sg_target" {
  name_prefix     = "db-sg-target"
  vpc_id          = module.target_db_vpc.vpc_id

  ingress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [module.target_db_vpc.vpc_cidr_block]
  }
  tags = merge(var.common_tags,
    {
      Name        = "db-sg-target"
    }
  )
}

resource "aws_security_group" "db_sg_source" {
  name_prefix     = "db-sg-source"
  vpc_id          = module.source_db_vpc.vpc_id

  ingress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [module.source_db_vpc.vpc_cidr_block]
  }
  tags = merge(var.common_tags,
    {
      Name        = "db-sg-sourcet"
    }
  )
}

#################
# resource "aws_db_subnet_group" "subnet_group_2" {
#   name_prefix   = "subnet-grp-"
#   subnet_ids    = module.source_db_vpc.private_subnets

#   tags = {
#     Name = "postgres-subnet-group"
#   }
# }

# resource "aws_db_instance" "source_db" {
#   identifier              = "source-db"
#   allocated_storage       = 20
#   engine                  = "postgres"
#   instance_class          = "db.t3.micro"
#   port                    = 5432
#   username                = local.db_creds_source.username
#   password                = local.db_creds_source.password
#   db_subnet_group_name    = aws_db_subnet_group.subnet_group_2.name
#   vpc_security_group_ids  = [aws_security_group.db_sg_2.id]
#   publicly_accessible     = false
#   apply_immediately       = true
#   skip_final_snapshot     = true
#   tags = merge(var.common_tags,
#     {
#       Name        = "postgres"
#     }
#   )
# }



resource "aws_secretsmanager_secret" "masterdb_secret_2" {
   name_prefix = "source_db_"
}


resource "aws_secretsmanager_secret_version" "source_db_secret" {
  secret_id = aws_secretsmanager_secret.masterdb_secret_2.id
  secret_string = jsonencode({
    "username"             = "postgres"
    "password"             = "${random_string.source_db.id}"
  })
}

# sec group for source db
# resource "aws_security_group" "db_sg_2" {
#   name_prefix        = "db-sg-"
#   vpc_id             = module.source_db_vpc.vpc_id

#   ingress {
#     from_port        = 5432
#     to_port          = 5432
#     protocol         = "tcp"
#     cidr_blocks      = [module.source_db_vpc.vpc_cidr_block]
#   }
#   tags = merge(var.common_tags,
#     {
#       Name        = "db-sg-"
#     }
#   )
# }

##################################################### EC2 Host in DMS VPC

resource "aws_network_interface" "ec2_nic" {
  subnet_id       = module.dms_vpc.private_subnets[0]
  security_groups = [aws_security_group.ec2_sg.id]
}

resource "aws_instance" "ec2" {
  ami                   = data.aws_ami.amazon_linux_2.id
  iam_instance_profile  = aws_iam_instance_profile.ec2_instance_profile.name 
  instance_type         = var.instance_size
  user_data             = file("../scripts/user_data.sh")

  network_interface {
    network_interface_id = aws_network_interface.ec2_nic.id
    device_index         = 0
  }

  tags = merge(var.common_tags,
    {
      Name        = "bastion-host"
    }
  )
}

resource "aws_security_group" "ec2_sg" {
  name_prefix       = "ec2-SG-"
  vpc_id            = module.dms_vpc.vpc_id

 #needed for postgres
  egress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [module.dms_vpc.vpc_cidr_block] 
  }

  #needed for ssm
  egress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [module.dms_vpc.vpc_cidr_block]
  }

  # needed for s3 bucket linux repositories
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    prefix_list_ids  = [aws_vpc_endpoint.s3_gateway_endpoint.prefix_list_id]
  }

  tags = merge(var.common_tags,
    {
      Name        = "ec2-SG"
    }
  )
}

# linux repo
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id                = module.dms_vpc.vpc_id
  service_name          = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type     = "Gateway"
  route_table_ids       = module.dms_vpc.private_route_table_ids

  tags = merge(var.common_tags,
    {
      Name        = "S3-EP"
    }
  )
}

################################################# SSM Endpoints DMS VPC

resource "aws_vpc_endpoint" "ssm" {
  vpc_id                = module.dms_vpc.vpc_id
  service_name          = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type     = "Interface"
  security_group_ids    = [aws_security_group.ssm_sec_grp.id]
  private_dns_enabled   = true
  subnet_ids            = tolist(module.dms_vpc.private_subnets)
  tags = merge(var.common_tags,
    {
      Name        = "SSM-EP"
    }
  )
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id                = module.dms_vpc.vpc_id
  service_name          = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type     = "Interface"
  security_group_ids    = [aws_security_group.ssm_sec_grp.id]
  private_dns_enabled   = true
  subnet_ids            = tolist(module.dms_vpc.private_subnets)
  tags = merge(var.common_tags,
    {
      Name        = "EC2Messages-EP"
    }
  )
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id                = module.dms_vpc.vpc_id
  service_name          = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type     = "Interface"
  security_group_ids    = [aws_security_group.ssm_sec_grp.id]
  private_dns_enabled   = true
  subnet_ids            = tolist(module.dms_vpc.private_subnets)
  tags = merge(var.common_tags,
    {
      Name        = "SSMMessages-EP"
    }
  )
}

resource "aws_security_group" "ssm_sec_grp" {
  name_prefix     = "ssm-ep-sg-"
  vpc_id          = module.dms_vpc.vpc_id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [module.dms_vpc.vpc_cidr_block]
  }

  tags = merge(var.common_tags,
    {
      Name        = "ssm-ep-sg"
    }
  )
}