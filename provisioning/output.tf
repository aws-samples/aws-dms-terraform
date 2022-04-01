output "source_db_vpc_id" {
  value = module.source_db_vpc.vpc_id
}

output "source_db_vpc_cidr_block" {
  value = module.source_db_vpc.vpc_cidr_block
}

output "source_db_vpc_arn" {
  value = module.source_db_vpc.vpc_arn
}

output "source_db_vpc_private_rt" {
  value =  module.source_db_vpc.private_route_table_ids
}

output "dms_vpc_id" {
  value = module.dms_vpc.vpc_id
}

output "dms_vpc_cidr_block" {
  value = module.dms_vpc.vpc_cidr_block
}

output "dms_vpc_arn" {
  value = module.dms_vpc.vpc_arn
}

output "dms_vpc_private_rt" {
  value =  module.dms_vpc.private_route_table_ids
}

output "target_db_vpc_id" {
  value = module.target_db_vpc.vpc_id
}

output "target_db_vpc_cidr_block" {
  value = module.target_db_vpc.vpc_cidr_block
}

output "target_db_vpc_arn" {
  value = module.target_db_vpc.vpc_arn
}

output "target_db_vpc_private_rt" {
  value =  module.target_db_vpc.private_route_table_ids
}