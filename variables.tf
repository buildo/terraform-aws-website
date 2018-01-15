variable "domain" {
  type        = "string"
  description = "The domain where to host the site. This must be the naked domain, e.g. `example.com`"
}

variable "enable_health_check" {
  type        = "string"
  default     = false
  description = "If true, it creates a Route53 health check that monitors the www endpoint and an alarm that triggers whenever it's not reachable. Please note this comes at an extra monthly cost on your AWS account"
}

variable "health_check_alarm_sns_topics" {
  type        = "list"
  default     = []
  description = "A list of SNS topics to notify whenever the health check fails or comes back to normal"
}

variable "enable_gzip" {
  type        = "string"
  default     = true
  description = "Whether to make CloudFront automatically compress content for web requests that include `Accept-Encoding: gzip` in the request header"
}
