data "aws_route53_zone" "main" {
  count        = var.create_hosted_zone ? 0 : 1
  name         = var.hosted_zone
  private_zone = false
}

resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.hosted_zone

  tags = {
    Service = "core"
  }
}

locals {
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main[0].zone_id
  app_domain     = "${var.environment}.${var.hosted_zone}"
}

resource "aws_route53_record" "static" {
  zone_id         = local.hosted_zone_id
  name            = "static.${local.app_domain}"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.static.domain_name
    zone_id                = aws_cloudfront_distribution.static.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id         = local.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_route53_record" "alb_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id         = local.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_route53_record" "api" {
  zone_id         = local.hosted_zone_id
  name            = "api.${local.app_domain}"
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ui" {
  zone_id         = local.hosted_zone_id
  name            = "ui.${local.app_domain}"
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "console" {
  zone_id         = local.hosted_zone_id
  name            = "console.${local.app_domain}"
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}
