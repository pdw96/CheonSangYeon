terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-s3-cheonsangyeon"
    key            = "terraform/global-route53/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-Dynamo-CheonSangYeon"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Import CloudFront state
data "terraform_remote_state" "cloudfront" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-cloudfront/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Import Seoul state
data "terraform_remote_state" "seoul" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/seoul/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Import Tokyo state
data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/tokyo/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ===== Route 53 Hosted Zone =====
resource "aws_route53_zone" "main" {
  name    = "pdwo610.shop"
  comment = "CheonSangYeon Public Domain"

  tags = {
    Name        = "pdwo610.shop"
    Environment = "production"
    Terraform   = "true"
  }
}

# ===== ACM Certificate for CloudFront (us-east-1) =====
resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us_east_1
  domain_name       = "pdwo610.shop"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.pdwo610.shop"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "pdwo610.shop-cloudfront"
    Environment = "production"
    Terraform   = "true"
  }
}

# DNS Validation Records for ACM Certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# Wait for Certificate Validation
# Note: This requires the domain to be registered and NS records to be set at registrar
# If domain is not registered, comment this out and manually validate later
resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "45m"  # Extended timeout for DNS propagation
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ===== CloudFront Alias Record =====
resource "aws_route53_record" "cloudfront_root" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "pdwo610.shop"
  type    = "A"

  alias {
    name                   = data.terraform_remote_state.cloudfront.outputs.cloudfront_domain_name
    zone_id                = data.terraform_remote_state.cloudfront.outputs.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloudfront_root_ipv6" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "pdwo610.shop"
  type    = "AAAA"

  alias {
    name                   = data.terraform_remote_state.cloudfront.outputs.cloudfront_domain_name
    zone_id                = data.terraform_remote_state.cloudfront.outputs.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# WWW subdomain
resource "aws_route53_record" "cloudfront_www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.pdwo610.shop"
  type    = "A"

  alias {
    name                   = data.terraform_remote_state.cloudfront.outputs.cloudfront_domain_name
    zone_id                = data.terraform_remote_state.cloudfront.outputs.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloudfront_www_ipv6" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.pdwo610.shop"
  type    = "AAAA"

  alias {
    name                   = data.terraform_remote_state.cloudfront.outputs.cloudfront_domain_name
    zone_id                = data.terraform_remote_state.cloudfront.outputs.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# ===== Regional Subdomains (Optional) =====
# Seoul region direct access
resource "aws_route53_record" "seoul" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "seoul.pdwo610.shop"
  type    = "CNAME"
  ttl     = 300
  records = [data.terraform_remote_state.seoul.outputs.beanstalk_cname]
}

# Tokyo region direct access
resource "aws_route53_record" "tokyo" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "tokyo.pdwo610.shop"
  type    = "CNAME"
  ttl     = 300
  records = [data.terraform_remote_state.tokyo.outputs.beanstalk_cname]
}

# ===== Health Checks (Optional) =====
resource "aws_route53_health_check" "seoul_beanstalk" {
  fqdn              = data.terraform_remote_state.seoul.outputs.beanstalk_cname
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "seoul-beanstalk-health-check"
  }
}

resource "aws_route53_health_check" "tokyo_beanstalk" {
  fqdn              = data.terraform_remote_state.tokyo.outputs.beanstalk_cname
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "tokyo-beanstalk-health-check"
  }
}

# ===== MX Records (Email - Optional) =====
# resource "aws_route53_record" "mx" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "cloudupcon.com"
#   type    = "MX"
#   ttl     = 3600
#   records = [
#     "10 mail.cloudupcon.com",
#   ]
# }

# ===== TXT Records (SPF, DKIM - Optional) =====
resource "aws_route53_record" "txt_spf" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "pdwo610.shop"
  type    = "TXT"
  ttl     = 3600
  records = [
    "v=spf1 -all"  # No email sending allowed (adjust as needed)
  ]
}

# ===== CAA Records (Certificate Authority Authorization) =====
resource "aws_route53_record" "caa" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "pdwo610.shop"
  type    = "CAA"
  ttl     = 3600
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \"amazon.com\"",
  ]
}
