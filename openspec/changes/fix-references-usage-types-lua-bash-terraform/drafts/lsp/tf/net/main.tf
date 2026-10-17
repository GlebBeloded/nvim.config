variable "cidr" {
  type = string
}

output "vpc_id" {
  value = "vpc-${var.cidr}"
}
