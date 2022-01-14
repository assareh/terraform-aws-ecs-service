###########################
## AWS Provider - Main ##
###########################

# Define Terraform provider
terraform {
  required_version = ">= 0.12" # required for default tags
  required_providers {
    aws = {
      version = "~> 3.38" # required for default tags
    }
  }
}
