# Add the resources relatedo to the provider

resource "aws_s3_bucket" "s3_static_bucket" {
  bucket = "static-website-${var.env}-${local.account_id}"

  tags = {
    Environment = var.env
  }
}

resource "aws_s3_bucket_ownership_controls" "static_ownership" {
  bucket = aws_s3_bucket.s3_static_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [aws_s3_bucket.s3_static_bucket]
}

resource "aws_s3_bucket_acl" "static_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.static_ownership]

  bucket = aws_s3_bucket.s3_static_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_website_configuration" "static_config" {
  bucket = aws_s3_bucket.s3_static_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  depends_on = [aws_s3_bucket.s3_static_bucket]

}

resource "aws_iam_policy" "static_s3_policy" {
  name        = "s3Policy-${var.env}"
  description = "My static s3 policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.s3_static_bucket.arn,
          "${aws_s3_bucket.s3_static_bucket.arn}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role" "static_s3_role" {
  name = "s3Role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:user/EddZuleta"
        }
      },
    ]
  })

  tags = {
    Environment = var.env
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.static_s3_role.name
  policy_arn = aws_iam_policy.static_s3_policy.arn
}


resource "aws_s3_bucket" "s3_logging_bucket" {
  bucket = "logging-bucket-${var.env}-${local.account_id}"

  tags = {
    Environment = var.env
  }
}

resource "aws_s3_bucket_ownership_controls" "logging_ownership" {
  bucket = aws_s3_bucket.s3_logging_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [aws_s3_bucket.s3_logging_bucket]
}

resource "aws_s3_bucket_acl" "logging_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.logging_ownership]

  bucket = aws_s3_bucket.s3_logging_bucket.id

  access_control_policy {
    grant {
      grantee {
        id   = data.aws_canonical_user_id.current.id
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }

    owner {
      id = data.aws_canonical_user_id.current.id
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.s3_static_bucket.id
  policy = data.aws_iam_policy_document.this.json
}


resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "cloudfront-oac-${var.env}"
  description                       = "Example Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.s3_static_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = local.s3_origin_id
  }

  enabled = true

  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.s3_logging_bucket.bucket_regional_domain_name
    prefix          = "logs/"
  }


  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Environment = var.env
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}