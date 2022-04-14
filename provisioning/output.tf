output "source_db_vpc_id" {
  value = module.source_db_vpc.vpc_id
}

output "source_db_vpc_cidr_block" {
  value = module.source_db_vpc.vpc_cidr_block
}

# output "source_db_vpc_arn" {
#   value = module.source_db_vpc.vpc_arn
# }

# output "source_db_vpc_private_rt" {
#   value =  module.source_db_vpc.private_route_table_ids
# }

output "dms_vpc_id" {
  value = module.dms_vpc.vpc_id
}

output "dms_vpc_cidr_block" {
  value = module.dms_vpc.vpc_cidr_block
}

# output "dms_vpc_arn" {
#   value = module.dms_vpc.vpc_arn
# }

# output "dms_vpc_private_rt" {
#   value =  module.dms_vpc.private_route_table_ids
# }

output "target_db_vpc_id" {
  value = module.target_db_vpc.vpc_id
}

output "target_db_vpc_cidr_block" {
  value = module.target_db_vpc.vpc_cidr_block
}

# output "target_db_vpc_arn" {
#   value = module.target_db_vpc.vpc_arn
# }

# output "target_db_vpc_private_rt" {
#   value =  module.target_db_vpc.private_route_table_ids
# }

output "target_vpc_endpoint" {
  value =  aws_vpc_endpoint.target_endpoint.dns_entry[0]["dns_name"]
}

output "source_vpc_endpoint" {
  value =  aws_vpc_endpoint.source_endpoint.dns_entry[0]["dns_name"]
}

output "secret_source_db" {
  value =  random_string.source_db.id
}

output "secret_target_db" {
  value =  random_string.target_db.id
}

# output "aurora_postgres_writer_endpoint" {
#   value =  module.cluster_endpoint
# }


# output "cluster_db_name" {
#   value = module.cluster.cluster_database_name
# }

# output "cluster_username" {
#   value = module.cluster.cluster_master_username
#   sensitive = true
# }

# output "cluster_pwd" {
#   value = module.cluster.cluster_master_password
#   sensitive = true
# }
