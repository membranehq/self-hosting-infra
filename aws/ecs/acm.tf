resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us-east-1
  domain_name       = "static.${local.app_domain}"
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
  domain_name = local.app_domain
  subject_alternative_names = [
    "api.${local.app_domain}",
    "ui.${local.app_domain}",
    "console.${local.app_domain}"
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
