# CloudFront CDN 모듈

## 개요

Seoul과 Tokyo Beanstalk을 Origin으로 사용하는 CloudFront Distribution을 관리합니다.

## 🔧 커스텀 도메인 사용 방법

### 1. 기본 배포 (CloudFront 도메인만 사용)

```bash
cd global/cloudfront
terraform init
terraform apply
```

이 경우 `*.cloudfront.net` 도메인만 사용됩니다.

### 2. 커스텀 도메인 활성화

#### Step 1: Route 53 먼저 배포

```bash
cd global/route53
# variables.tf에서 domain_name 변경
terraform apply
```

#### Step 2: CloudFront 변수 설정

**방법 A: variables.tf 수정 (권장)**

```terraform
variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "your-domain.com"  # ← Route 53과 동일하게 설정
}

variable "enable_custom_domain" {
  description = "Enable custom domain configuration"
  type        = bool
  default     = true  # ← true로 변경
}
```

**방법 B: terraform.tfvars 사용**

```hcl
domain_name          = "your-domain.com"
enable_custom_domain = true
```

#### Step 3: CloudFront 배포

```bash
terraform apply
```

## 주요 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `domain_name` | `pdwo610.shop` | 커스텀 도메인명 (Route 53과 일치해야 함) |
| `enable_custom_domain` | `false` | 커스텀 도메인 활성화 여부 |
| `price_class` | `PriceClass_All` | CloudFront 가격 등급 |
| `geo_restriction_type` | `none` | 지역 제한 타입 |
| `enable_waf` | `false` | WAF 활성화 여부 |

## 주요 기능

### 1. Multi-Origin Failover
- **Primary Origin**: Seoul Beanstalk (ap-northeast-2)
- **Failover Origin**: Tokyo Beanstalk (ap-northeast-1)
- **자동 장애 조치**: 5xx, 4xx 에러 발생 시 자동으로 Tokyo로 전환

### 2. 최적화된 캐싱 전략
- **Static Assets** (`/static/*`): 최대 1년 캐싱
- **API Endpoints** (`/api/*`): 캐싱 없음 (실시간 데이터)
- **Default**: 동적 콘텐츠 최적화 (1일 캐싱)

### 3. 보안 강화
- HTTPS 강제 리다이렉트
- HTTP/2, HTTP/3 (QUIC) 지원
- 보안 헤더 자동 추가:
  - Strict-Transport-Security (HSTS)
  - X-Content-Type-Options
  - X-Frame-Options
  - X-XSS-Protection
  - Referrer-Policy

### 4. 글로벌 성능
- **Price Class**: PriceClass_All (전 세계 모든 엣지 로케이션)
- **Compression**: Gzip, Brotli 압축 지원
- **HTTP/3**: QUIC 프로토콜 지원

### 5. CloudFront Functions
- URL Rewrite: SPA (Single Page Application) 라우팅 지원
- `/about`, `/contact` → `/index.html`

## 배포 방법

```bash
cd global/cloudfront
terraform init
terraform plan
terraform apply
```

## 배포 후 확인

```bash
# CloudFront URL 확인
terraform output cloudfront_url

# Distribution 상태 확인
terraform output cloudfront_status
```

## 테스트

```bash
# CloudFront를 통한 접속
curl https://[cloudfront-domain].cloudfront.net

# 장애 조치 테스트 (Seoul Beanstalk 중지 후)
curl https://[cloudfront-domain].cloudfront.net
# → Tokyo Beanstalk로 자동 전환됨
```

## 커스텀 도메인 설정 (선택 사항)

1. **ACM 인증서 생성** (us-east-1 리전에서):
```bash
aws acm request-certificate \
  --domain-name example.com \
  --validation-method DNS \
  --region us-east-1
```

2. **variables.tf 수정**:
```hcl
custom_domain         = "example.com"
acm_certificate_arn   = "arn:aws:acm:us-east-1:..."
```

3. **main.tf의 viewer_certificate 블록 수정** (주석 해제)

4. **Route53에 ALIAS 레코드 추가**

## WAF 설정 (선택 사항)

추가 보안을 위해 AWS WAF 연동 가능:

```hcl
# main.tf에 추가
resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1
  name     = "cheonsangyeon-waf"
  scope    = "CLOUDFRONT"
  # ...
}

# CloudFront Distribution에 연결
web_acl_id = aws_wafv2_web_acl.cloudfront.arn
```

## 모니터링

- **CloudWatch Metrics**: CloudFront 트래픽, 에러율, 캐시 히트율
- **Access Logs**: S3 버킷에 로그 저장 (선택 사항)

## 비용

- **PriceClass_All**: 전 세계 엣지 로케이션 사용 (최고 성능, 최고 비용)
- **데이터 전송**: 송신 데이터에 대해 과금
- **HTTPS 요청**: 요청 수에 대해 과금
- **Lambda@Edge/CloudFront Functions**: 실행 횟수 및 시간에 대해 과금

## 주요 리소스

- `aws_cloudfront_distribution.main`: 메인 CloudFront 배포
- `aws_cloudfront_cache_policy.optimized`: 최적화된 캐시 정책
- `aws_cloudfront_origin_request_policy.all_viewer`: Origin 요청 정책
- `aws_cloudfront_response_headers_policy.security_headers`: 보안 헤더 정책
- `aws_cloudfront_function.url_rewrite`: URL 재작성 함수

## 참고사항

1. CloudFront 배포는 생성/수정 시 15-20분 소요
2. 캐시 무효화(invalidation)는 비용 발생 (월 1,000개 무료)
3. SSL/TLS 인증서는 반드시 us-east-1 리전에서 생성
4. Origin 변경 후에는 캐시 무효화 필요
