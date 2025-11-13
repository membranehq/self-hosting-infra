resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us-east-1
  domain_name       = "static.${var.environment}.${var.hosted_zone_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_cert_validation : record.fqdn]

  timeouts {
    create = "45m"
  }
}

# ACM certificate for ALB (Application Load Balancer) - must be in same region as ALB
resource "aws_acm_certificate" "alb" {
  domain_name = "${var.environment}.${var.hosted_zone_name}"
  subject_alternative_names = [
    "*.${var.environment}.${var.hosted_zone_name}"
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Service = "alb"
  }
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in aws_route53_record.alb_cert_validation : record.fqdn]

  timeouts {
    create = "45m"
  }
}
