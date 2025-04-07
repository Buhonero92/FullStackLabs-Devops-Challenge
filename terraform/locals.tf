locals {
  account_id   = data.aws_caller_identity.identity.account_id
  s3_origin_id = "myS3Origin"
}