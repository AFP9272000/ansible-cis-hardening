output "instance_ids" {
  description = "IDs of the hardening targets."
  value       = aws_instance.target[*].id
}

output "instance_public_ips" {
  description = "Public IPs of the hardening targets."
  value       = aws_instance.target[*].public_ip
}

output "ami_id" {
  description = "Resolved Ubuntu 24.04 AMI."
  value       = data.aws_ami.ubuntu_2404.id
}
