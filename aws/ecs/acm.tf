resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us-east-1
  domain_name       = "static.int-membrane.com"
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

resource "aws_acm_certificate" "alb" {
  domain_name = "int-membrane.com"
  subject_alternative_names = [
    "api.int-membrane.com",
    "ui.int-membrane.com",
    "console.int-membrane.com"
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in aws_route53_record.alb_cert_validation : record.fqdn]

  timeouts {
    create = "45m"
  }
}
