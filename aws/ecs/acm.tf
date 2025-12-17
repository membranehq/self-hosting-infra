resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us-east-1
  domain_name       = "static.${var.environment}.${aws_route53_zone.main.name}"
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
  domain_name = "${var.environment}.${aws_route53_zone.main.name}"
  subject_alternative_names = [
    "api.${var.environment}.${aws_route53_zone.main.name}",
    "ui.${var.environment}.${aws_route53_zone.main.name}",
    "console.${var.environment}.${aws_route53_zone.main.name}"
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
