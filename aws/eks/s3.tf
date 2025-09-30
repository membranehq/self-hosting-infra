resource "aws_s3_bucket" "tmp" {
  bucket = "${var.environment}-integration-app-tmp"

  tags = {
    Service = "api"
  }
}

resource "aws_s3_bucket" "connectors" {
  bucket = "${var.environment}-integration-app-connectors"

  tags = {
    Service = "api"
  }
}

resource "aws_s3_bucket" "static" {
  bucket = "${var.environment}-integration-app-static"

  tags = {
    Service = "api"
  }
}

# Lifecycle rules for tmp bucket
resource "aws_s3_bucket_lifecycle_configuration" "tmp" {
  bucket = aws_s3_bucket.tmp.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7
    }
  }
}

# CORS configuration for static bucket
resource "aws_s3_bucket_cors_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "static_cloudfront" {
  bucket = aws_s3_bucket.static.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.static.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.static.arn
          }
        }
      }
    ]
  })
}
