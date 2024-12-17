data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}"]
  }
}

data "aws_subnets" "private_subnets" {
  # EKS Private Subnet tags
  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
  # Filter by VPC ID
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

data "aws_subnets" "public_subnets" {
  # EKS Public Subnet tags
  filter {
    name   = "tag:kubernetes.io/role/elb"
    values = ["1"]
  }
  # Filter by VPC ID
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}
