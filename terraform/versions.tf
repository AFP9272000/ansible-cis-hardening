terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # For CI-driven runs that must persist state between jobs, switch to a
  # remote backend. Local state is fine that applies and destroys
  # within the same session.
  #
  # backend "s3" {
  #   bucket       = "your-tfstate-bucket"
  #   key          = "ansible-cis-hardening-lab/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true
  # }
}
