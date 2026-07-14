provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ansible-cis-hardening-lab"
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}
