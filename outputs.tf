output "main_bucket_domain_name" {
  value = "${aws_s3_bucket.main.bucket_domain_name}"
}

output "main_bucket_id" {
  value = "${aws_s3_bucket.main.id}"
}

output "main_bucket_arn" {
  value = "${aws_s3_bucket.main.arn}"
}
