# Route 53 DNS 모듈

## 개요

이 모듈은 Route 53 Hosted Zone, ACM 인증서, DNS 레코드를 관리합니다.

## 🔧 도메인 변경 방법

### 방법 1: variables.tf 수정 (권장)

`variables.tf`에서 도메인만 변경하면 됩니다:

```terraform
variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "your-domain.com"  # ← 여기만 변경!
}
```

### 방법 2: terraform.tfvars 사용

프로젝트 루트에 `terraform.tfvars` 파일 생성:

```hcl
domain_name = "your-domain.com"
```

### 방법 3: 명령줄에서 변수 전달

```bash
terraform apply -var="domain_name=your-domain.com"
```

## 배포 방법

### 1. Route 53 설정
```bash
cd global/route53
terraform init
terraform plan
terraform apply
```

### 2. Name Server 설정
배포 완료 후 출력된 Name Server를 도메인 등록 기관(registrar)에 설정해야 합니다.

```bash
# Name Server 확인
terraform output route53_name_servers
```

**출력 예시:**
```
[
  "ns-123.awsdns-12.com",
  "ns-456.awsdns-45.net",
  "ns-789.awsdns-78.org",
  "ns-012.awsdns-01.co.uk"
]
```

**도메인 등록 기관에서 설정:**
1. 도메인 등록 기관 관리 페이지 접속
2. DNS 설정 또는 Name Server 설정 메뉴로 이동
3. 위 4개의 Name Server를 등록
4. 변경 사항 저장

**주의:** Name Server 변경은 전파에 최대 48시간이 걸릴 수 있습니다.

### 3. SSL/TLS 인증서 검증
ACM 인증서는 DNS 검증 방식을 사용합니다. Terraform이 자동으로 검증 레코드를 생성하고 검증을 완료합니다.

```bash
# 인증서 상태 확인
terraform output acm_certificate_status
# 출력: ISSUED (검증 완료)
```

## 생성되는 리소스

### 도메인: `{domain_name}` (변수로 관리)

- **Hosted Zone**: `{domain_name}`
- **ACM Certificate**: `{domain_name}`, `*.{domain_name}`
- **DNS Records**:
  - `{domain_name}` (A/AAAA) → CloudFront
  - `www.{domain_name}` (A/AAAA) → CloudFront
  - `seoul.{domain_name}` (CNAME) → Seoul Beanstalk
  - `tokyo.{domain_name}` (CNAME) → Tokyo Beanstalk
- **Health Checks**: Seoul, Tokyo Beanstalk

## 출력 값

```bash
terraform output
```

주요 출력:
- `route53_zone_id`: Hosted Zone ID
- `route53_name_servers`: NS 레코드 (도메인 등록 기관에 설정 필요)
- `domain_name`: 현재 도메인명
- `acm_certificate_arn`: ACM 인증서 ARN
- `cloudfront_url`: https://{domain_name}
- `www_url`: https://www.{domain_name}
- `seoul_url`: https://seoul.{domain_name}
- `tokyo_url`: https://tokyo.{domain_name}

## DNS 레코드 구조

모든 레코드는 `domain_name` 변수를 사용하여 자동 생성됩니다.

| 레코드 | 타입 | 값 | 목적 |
|--------|------|-----|------|
| {domain_name} | A (Alias) | CloudFront | 메인 도메인 |
| {domain_name} | AAAA (Alias) | CloudFront | 메인 도메인 (IPv6) |
| www.{domain_name} | A (Alias) | CloudFront | WWW 서브도메인 |
| www.{domain_name} | AAAA (Alias) | CloudFront | WWW 서브도메인 (IPv6) |
| seoul.{domain_name} | CNAME | Seoul Beanstalk | Seoul 리전 직접 접속 |
| tokyo.{domain_name} | CNAME | Tokyo Beanstalk | Tokyo 리전 직접 접속 |
| {domain_name} | TXT | SPF 레코드 | 이메일 스푸핑 방지 |
| {domain_name} | CAA | amazon.com | 인증서 발급 기관 제한 |

## 접속 URL

모든 URL은 변수로 관리됩니다:

- **메인 사이트**: https://{domain_name}
- **WWW**: https://www.{domain_name}
- **Seoul 직접**: https://seoul.{domain_name}
- **Tokyo 직접**: https://tokyo.{domain_name}

## Health Checks

Route 53 Health Check가 Seoul과 Tokyo Beanstalk 환경을 30초마다 모니터링합니다.

- 프로토콜: HTTP
- 포트: 80
- 경로: /
- 실패 임계값: 3회
- 체크 간격: 30초

## 검증

### DNS 전파 확인
```bash
# Name Server 확인 (도메인 변수 사용)
DOMAIN=$(terraform output -raw domain_name)
dig NS $DOMAIN

# A 레코드 확인
dig A $DOMAIN

# CNAME 레코드 확인
dig CNAME www.$DOMAIN
```

### 인증서 확인
```bash
# SSL 인증서 확인 (도메인 변수 사용)
DOMAIN=$(terraform output -raw domain_name)
openssl s_client -connect $DOMAIN:443 -servername $DOMAIN
```

### 웹사이트 접속 테스트
```bash
DOMAIN=$(terraform output -raw domain_name)

# 메인 도메인
curl -I https://$DOMAIN

# WWW
curl -I https://www.$DOMAIN

# Seoul
curl -I https://seoul.$DOMAIN

# Tokyo
curl -I https://tokyo.$DOMAIN
```

## 비용

- **Route 53 Hosted Zone**: $0.50/월
- **DNS 쿼리**: 처음 10억 쿼리당 $0.40 (이후 $0.20)
- **Health Checks**: $0.50/월 (각 health check당)
- **ACM 인증서**: 무료

## 주의사항

1. **Name Server 설정**: 반드시 도메인 등록 기관에서 Route 53 Name Server를 설정해야 합니다.
2. **DNS 전파 시간**: 최대 48시간 소요될 수 있습니다.
3. **ACM 인증서**: us-east-1 리전에서만 생성 가능 (CloudFront용)
4. **HTTPS**: 인증서 검증 완료 후 CloudFront 업데이트 필요

## 추가 기능

### DNSSEC 활성화 (선택 사항)
```hcl
# main.tf에 추가
resource "aws_route53_dnssec_key_signing_key" "main" {
  hosted_zone_id = aws_route53_zone.main.id
  name           = "cloudupcon-ksk"
}

resource "aws_route53_hosted_zone_dnssec" "main" {
  hosted_zone_id = aws_route53_zone.main.id
  signing_status = "SIGNING"
  
  depends_on = [aws_route53_dnssec_key_signing_key.main]
}
```

### 이메일 설정 (MX 레코드)
main.tf의 주석 처리된 MX 레코드 부분을 활성화하고 이메일 서버 주소로 수정하세요.

### Geolocation Routing (지역 기반 라우팅)
특정 지역 사용자를 특정 리전으로 라우팅하려면 Geolocation routing policy를 사용하세요.
