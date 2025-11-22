terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-s3-cheonsangyeon"
    key            = "terraform/global-cloudfront/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-Dynamo-CheonSangYeon"
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"  # CloudFront SSL 인증서는 us-east-1에서만 생성 가능
}

provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

# Import Seoul and Tokyo Terraform states
data "terraform_remote_state" "seoul" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/seoul/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/tokyo/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Import Route 53 state for ACM certificate
data "terraform_remote_state" "route53" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-route53/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ===== Origin Access Control for CloudFront =====
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "cheonsangyeon-oac"
  description                       = "Origin Access Control for Beanstalk origins"
  origin_access_control_origin_type = "s3"  # Beanstalk ALB는 custom origin 사용
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ===== Cache Policy (최적화) =====
resource "aws_cloudfront_cache_policy" "optimized" {
  name        = "cheonsangyeon-optimized-cache"
  comment     = "Optimized cache policy for dynamic web application"
  default_ttl = 86400    # 1일
  max_ttl     = 31536000 # 1년
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"  # 세션 쿠키 전달
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Host", "CloudFront-Forwarded-Proto", "CloudFront-Is-Desktop-Viewer", "CloudFront-Is-Mobile-Viewer"]
      }
    }

    query_strings_config {
      query_string_behavior = "all"  # 쿼리 스트링 전달
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# ===== Origin Request Policy =====
resource "aws_cloudfront_origin_request_policy" "all_viewer" {
  name    = "cheonsangyeon-all-viewer"
  comment = "Forward all viewer headers, cookies, and query strings"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# ===== Response Headers Policy (보안 강화) =====
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "cheonsangyeon-security-headers"
  comment = "Security headers for enhanced protection"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }

  custom_headers_config {
    items {
      header   = "X-Custom-Header"
      value    = "CheonSangYeon-CloudFront"
      override = true
    }
  }
}

# ===== CloudFront Distribution (Multi-Origin) =====
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CheonSangYeon Multi-Region Distribution"
  price_class         = "PriceClass_All"  # Pro: 전 세계 모든 엣지 로케이션 사용
  http_version        = "http2and3"       # HTTP/3 (QUIC) 지원
  default_root_object = "index.html"
  
  # Custom domain aliases
  aliases = ["pdwo610.shop", "www.pdwo610.shop"]

  # Origin 1: Seoul Beanstalk (Primary)
  origin {
    domain_name = data.terraform_remote_state.seoul.outputs.beanstalk_environment_url
    origin_id   = "seoul-beanstalk"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"  # Beanstalk ALB는 HTTP로 통신
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Origin-Region"
      value = "ap-northeast-2"
    }
  }

  # Origin 2: Tokyo Beanstalk (Failover)
  origin {
    domain_name = data.terraform_remote_state.tokyo.outputs.beanstalk_environment_url
    origin_id   = "tokyo-beanstalk"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Origin-Region"
      value = "ap-northeast-1"
    }
  }

  # Origin Group (High Availability - Failover)
  origin_group {
    origin_id = "beanstalk-group"

    failover_criteria {
      status_codes = [500, 502, 503, 504, 404, 403]
    }

    member {
      origin_id = "seoul-beanstalk"
    }

    member {
      origin_id = "tokyo-beanstalk"
    }
  }

  # Default Cache Behavior (Seoul Origin 사용, GET/HEAD만 허용)
  default_cache_behavior {
    target_origin_id       = "seoul-beanstalk"  # Origin Group 대신 직접 Origin 사용
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]  # POST/PUT/PATCH/DELETE 제거
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    cache_policy_id            = aws_cloudfront_cache_policy.optimized.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.all_viewer.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Ordered Cache Behavior: Static Assets (최대 캐싱)
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    target_origin_id = "seoul-beanstalk"  # Origin Group 대신 직접 Origin 사용

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    min_ttl     = 0
    default_ttl = 86400    # 1일
    max_ttl     = 31536000 # 1년

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]

      cookies {
        forward = "none"
      }
    }
  }

  # Ordered Cache Behavior: API Endpoints (캐시 없음, Origin Group 사용 불가)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "seoul-beanstalk"  # Origin Group 대신 직접 Origin 사용

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }
  }

  # Geographic Restrictions (필요 시 설정)
  restrictions {
    geo_restriction {
      restriction_type = "none"
      # locations        = ["KR", "JP"]  # 한국, 일본만 허용하려면 whitelist로 설정
    }
  }

  # SSL/TLS Certificate (HTTPS)
  viewer_certificate {
    acm_certificate_arn      = data.terraform_remote_state.route53.outputs.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Logging Configuration (선택 사항)
  # logging_config {
  #   include_cookies = false
  #   bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
  #   prefix          = "cloudfront/"
  # }

  # WAF Web ACL (추가 보안)
  # web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  tags = {
    Name        = "cheonsangyeon-cloudfront"
    Environment = "production"
    Terraform   = "true"
  }
}

# ===== CloudFront Function (URL Rewrite - 선택 사항) =====
resource "aws_cloudfront_function" "url_rewrite" {
  name    = "cheonsangyeon-url-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "URL rewrite for SPA routing"
  publish = true

  code = <<-EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // SPA routing: HTML 파일 확장자가 없으면 index.html로 리다이렉트
    if (!uri.includes('.')) {
        request.uri = '/index.html';
    }
    
    return request;
}
EOT
}

# ===== Outputs for monitoring =====
# CloudWatch Alarms, Route53 Health Checks 등 추가 가능
