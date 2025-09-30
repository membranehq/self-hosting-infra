terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
  }
}

provider "aws" {
  region = var.AWS_REGION

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
    }
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
    }
  }
}

provider "aws" {
  alias   = "eu-central-1"
  region  = "eu-central-1"
  profile = var.aws_profile
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
    }
  }
}

provider "aws" {
  alias  = "lb"
  region = var.AWS_REGION
}
