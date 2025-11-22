# Route 53 Configuration for cloudupcon.com

## 개요
cloudupcon.com 도메인을 Route 53에 설정하고 CloudFront 및 Beanstalk 환경과 연결합니다.

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

### 4. CloudFront에 커스텀 도메인 적용
Route 53 설정 완료 후 CloudFront를 업데이트해야 합니다.

```bash
cd ../cloudfront
```

`main.tf`의 `viewer_certificate` 블록을 다음과 같이 수정:
```hcl
viewer_certificate {
  acm_certificate_arn      = data.terraform_remote_state.route53.outputs.acm_certificate_arn
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"
}
```

그리고 `aliases` 추가:
```hcl
resource "aws_cloudfront_distribution" "main" {
  # ... 기존 설정 ...
  
  aliases = ["cloudupcon.com", "www.cloudupcon.com"]
  
  # ... 나머지 설정 ...
}
```

## DNS 레코드 구조

| 레코드 | 타입 | 값 | 목적 |
|--------|------|-----|------|
| cloudupcon.com | A (Alias) | CloudFront | 메인 도메인 |
| cloudupcon.com | AAAA (Alias) | CloudFront | 메인 도메인 (IPv6) |
| www.cloudupcon.com | A (Alias) | CloudFront | WWW 서브도메인 |
| www.cloudupcon.com | AAAA (Alias) | CloudFront | WWW 서브도메인 (IPv6) |
| seoul.cloudupcon.com | CNAME | Seoul Beanstalk | Seoul 리전 직접 접속 |
| tokyo.cloudupcon.com | CNAME | Tokyo Beanstalk | Tokyo 리전 직접 접속 |
| cloudupcon.com | TXT | SPF 레코드 | 이메일 스푸핑 방지 |
| cloudupcon.com | CAA | amazon.com | 인증서 발급 기관 제한 |

## 접속 URL

- **메인 사이트**: https://cloudupcon.com
- **WWW**: https://www.cloudupcon.com
- **Seoul 직접**: https://seoul.cloudupcon.com
- **Tokyo 직접**: https://tokyo.cloudupcon.com

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
# Name Server 확인
dig NS cloudupcon.com

# A 레코드 확인
dig A cloudupcon.com

# CNAME 레코드 확인
dig CNAME www.cloudupcon.com
```

### 인증서 확인
```bash
# SSL 인증서 확인
openssl s_client -connect cloudupcon.com:443 -servername cloudupcon.com
```

### 웹사이트 접속 테스트
```bash
# 메인 도메인
curl -I https://cloudupcon.com

# WWW
curl -I https://www.cloudupcon.com

# Seoul
curl -I https://seoul.cloudupcon.com

# Tokyo
curl -I https://tokyo.cloudupcon.com
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
