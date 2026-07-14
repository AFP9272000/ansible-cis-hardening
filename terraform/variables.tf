variable "aws_region" {
  description = "AWS region for the lab. Keep in sync with ansible/inventory/aws_ec2.yml."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to resource names."
  type        = string
  default     = "cis-lab"
}

variable "instance_count" {
  description = "Number of hardening target instances."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 3
    error_message = "Keep the lab between 1 and 3 instances."
  }
}

variable "instance_type" {
  description = "EC2 instance type for targets."
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to reach SSH on the targets. Use your public IP as x.x.x.x/32."
  type        = string

  validation {
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "Refusing to open SSH to the world. Provide a specific CIDR such as x.x.x.x/32."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for the lab key pair."
  type        = string
  default     = "~/.ssh/cis_lab.pub"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.20.1.0/24"
}
