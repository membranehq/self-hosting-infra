terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94.1"
    }
  }
  required_version = ">= 1.11.3"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Environment = var.environment
        Project     = var.project
        Application = "${var.project}-${var.environment}-eks"
        ManagedBy   = "terraform"
        Terraform   = "true"
      },
      var.cost_center != "" ? { CostCenter = var.cost_center } : {}
    )
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = merge(
      {
        Environment = var.environment
        Project     = var.project
        Application = var.project
        ManagedBy   = "terraform"
        Terraform   = "true"
      },
      var.cost_center != "" ? { CostCenter = var.cost_center } : {}
    )
  }
}
