variable "region" {
  type = string
}

variable "tags" {
  type = map(string)
}

locals {
  name   = "app-${var.region}"
  common = merge(var.tags, { region = var.region })
}

module "net" {
  source = "./net"
  cidr   = var.region
}

resource "aws_s3_bucket" "logs" {
  bucket = local.name
  tags   = local.common

  depends_on = [module.net, data.aws_ami.base]
}

data "aws_ami" "base" {
  owners = [var.region]
}

resource "aws_instance" "web" {
  ami       = data.aws_ami.base.id
  subnet_id = module.net.vpc_id
  tags      = { bucket = aws_s3_bucket.logs.arn, idx = var.tags["a"] }
}

output "bucket_arn" {
  value       = aws_s3_bucket.logs.arn
  description = "region ${var.region}"
}

output "summary" {
  value = { name = local.name, vpc = module.net.vpc_id }
}

output "nested" {
  value = join(",", [aws_s3_bucket.logs.id])
}
