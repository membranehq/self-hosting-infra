resource "aws_cloudfront_origin_access_control" "static" {
  name                              = "${var.environment}-static-oac"
  description                       = "OAC for static S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "static" {
  enabled             = true
  default_root_object = "index.html"

  aliases = ["static.${var.environment}.${var.hosted_zone_name}"]

  depends_on = [aws_acm_certificate_validation.cloudfront]

  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.static.id
    origin_access_control_id = aws_cloudfront_origin_access_control.static.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.static.id
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Service = "core"
  }
}
