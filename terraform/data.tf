data "aws_caller_identity" "identity" {

}

data "aws_canonical_user_id" "current" {

}

data "aws_iam_policy_document" "this" {
  statement {
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.static_s3_role.arn
      ]
    }
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.s3_static_bucket.arn,
      "${aws_s3_bucket.s3_static_bucket.arn}/*",
    ]
  }
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.s3_static_bucket.arn}/*"
    ]
  }
}
