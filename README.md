# website Terraform module

This is a Terraform module designed to automate the deploy of a static website.

This modules creates the following resources:

- two S3 buckets, one for the content (`www.example.com`), one for redirecting from the
  naked domain to www (named `example.com`)
- two CloudFront distribution, one per bucket, that also redirect from HTTP to HTTPS
- two Route53 alias records, one per CloudFront distribution

## Usage
### Prerequisites
You have to create a SSL certificate for both domains (www and naked) on AWS.
This step can't be automated, due to limitations of the AWS API.

Follow this instructions:

- Access the [Certificate Manager](https://console.aws.amazon.com/acm/) on the AWS console
- Switch to the `us-east-1` (N. Virginia) region.
  - 🚨 **This is CRUCIAL, as AWS requires certificates for CloudFront to be issued in this region**
- Click on "Request a certificate"
- Enter as a primary domain name the domain you want *with www*, for example: `www.buildo.io`
- Enter the naked domain as an additional domain name, for example `buildo.io`

You should be in this situation:

![image](https://user-images.githubusercontent.com/691940/34524695-bbb25322-f09c-11e7-9fc1-b20e4629b8db.png)

**NOTE**: ⚠️ the order is important, the `www` domain must come first!

- Follow the steps for verifying the domain

### Using the module
Using the module is as simple as:

```hcl
provider "aws" {
  region = "eu-west-1" // The region for the S3 buckets and the CloudFront distribution
}

// This hosted zone must already exist
data "aws_route53_zone" "mysite-com" {
  name = "mysite.com."
}

module "website" {
  source = "buildo/website/aws"
  domain = "mysite.com" // no www here
  hosted_zone_id = "${data.aws_route53_zone.mysite-com.zone_id}"

  # optional: enable health check on www.mysite.com
  enable_health_check = true
  health_check_alarm_sns_topics = [
    "<arn of a topic to notify for health check alarms>"
  ]
}
```
