output "vpc_id" {
  value = data.aws_vpc.selected.id
}

output "private_subnet_ids" {
  value = data.aws_subnets.private_subnets.ids
}

output "public_subnet_ids" {
  value = data.aws_subnets.public_subnets.ids
}
