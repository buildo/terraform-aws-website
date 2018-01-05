locals {
  www_domain = "www.${var.domain}"

  domains = [
    "${var.domain}",
    "${local.www_domain}",
  ]

  website_endpoints = [
    "${aws_s3_bucket.redirect.website_endpoint}",
    "${aws_s3_bucket.main.website_endpoint}",
  ]
}

resource "aws_s3_bucket" "main" {
  bucket = "${local.www_domain}"

  website = {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "aws_s3_bucket" "redirect" {
  bucket = "${var.domain}"

  website = {
    redirect_all_requests_to = "${aws_s3_bucket.main.id}"
  }
}

resource "aws_route53_record" "A" {
  count   = "${length(local.domains)}"
  zone_id = "${var.hosted_zone_id}"
  name    = "${element(local.domains, count.index)}"
  type    = "A"

  alias {
    name                   = "${element(aws_cloudfront_distribution.cdn.*.domain_name, count.index)}"
    zone_id                = "${element(aws_cloudfront_distribution.cdn.*.hosted_zone_id, count.index)}"
    evaluate_target_health = false
  }
}

data "aws_acm_certificate" "ssl" {
  count    = "${length(local.domains)}"
  provider = "aws.us-east-1"            // this is an AWS requirement
  domain   = "${local.www_domain}"
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_distribution" "cdn" {
  count               = "${length(local.domains)}"
  enabled             = true
  default_root_object = "${element(local.domains, count.index) == local.www_domain ? "index.html" : ""}"
  aliases             = ["${element(local.domains, count.index)}"]
  is_ipv6_enabled     = true

  origin {
    domain_name = "${element(local.website_endpoints, count.index)}"
    origin_id   = "S3-${element(local.domains, count.index)}"

    custom_origin_config {
      http_port                = "80"
      https_port               = "443"
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "${element(data.aws_acm_certificate.ssl.*.arn, count.index)}"
    minimum_protocol_version = "TLSv1"
    ssl_support_method       = "sni-only"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${element(local.domains, count.index)}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }
}

resource "aws_route53_health_check" "health_check" {
  depends_on        = ["aws_route53_record.A"]
  count             = "${var.enable_health_check ? 1 : 0}"
  fqdn              = "${local.www_domain}"
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name = "${local.www_domain}"
  }
}

resource "aws_cloudwatch_metric_alarm" "health_check_alarm" {
  provider            = "aws.us-east-1"
  count               = "${var.enable_health_check ? 1 : 0}"
  alarm_name          = "${local.www_domain}-health-check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1.0"
  alarm_description   = "This metric monitors the health of the endpoint"
  ok_actions          = "${var.health_check_alarm_sns_topics}"
  alarm_actions       = "${var.health_check_alarm_sns_topics}"
  treat_missing_data  = "breaching"

  dimensions {
    HealthCheckId = "${aws_route53_health_check.health_check.id}"
  }
}
