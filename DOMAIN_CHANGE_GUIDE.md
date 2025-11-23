# 도메인 변경 가이드

## 빠른 시작

도메인을 `example.com`으로 변경하려면 다음 2개 파일만 수정하면 됩니다:

### 1. Route 53 변수 수정

파일: `global/route53/variables.tf`

```terraform
variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "example.com"  # ← 여기만 변경!
}
```

### 2. CloudFront 변수 수정

파일: `global/cloudfront/variables.tf`

```terraform
variable "domain_name" {
  description = "Primary domain name (e.g., example.com)"
  type        = string
  default     = "example.com"  # ← Route 53과 동일하게 변경!
}

variable "enable_custom_domain" {
  description = "Enable custom domain configuration"
  type        = bool
  default     = true  # ← true로 변경
}
```

### 3. 배포

```bash
# 1. Route 53 배포
cd global/route53
terraform apply

# 2. Name Server 설정
terraform output route53_name_servers
# → 도메인 등록 기관에 NS 레코드 설정

# 3. ACM 인증서 검증 대기 (자동, 5-30분)

# 4. CloudFront 배포
cd ../cloudfront
terraform apply
```

## 전체 도메인 변경 체크리스트

- [ ] `global/route53/variables.tf`의 `domain_name` 변경
- [ ] `global/cloudfront/variables.tf`의 `domain_name` 변경
- [ ] `global/cloudfront/variables.tf`의 `enable_custom_domain = true`
- [ ] Route 53 배포
- [ ] NS 레코드 설정 (도메인 등록 기관)
- [ ] ACM 인증서 검증 확인
- [ ] CloudFront 배포

## terraform.tfvars 사용 (권장)

각 모듈 디렉토리에 `terraform.tfvars` 파일을 생성하면 더 편리합니다:

### global/route53/terraform.tfvars

```hcl
domain_name = "example.com"
```

### global/cloudfront/terraform.tfvars

```hcl
domain_name          = "example.com"
enable_custom_domain = true
price_class          = "PriceClass_200"  # 비용 절감 옵션
```

이렇게 하면 `terraform apply`만 실행하면 자동으로 변수가 적용됩니다.

## 여러 도메인 사용 시

여러 도메인을 사용하려면 별도의 Route 53 모듈을 복사하여 사용하세요:

```bash
cp -r global/route53 global/route53-domain2
```

그리고 각각 다른 도메인으로 설정하면 됩니다.

## 주의사항

⚠️ **중요**: Route 53과 CloudFront의 `domain_name`은 반드시 일치해야 합니다!

⚠️ **중요**: 도메인 변경 후에는 반드시 NS 레코드를 설정해야 ACM 인증서가 검증됩니다!

⚠️ **중요**: CloudFront 배포/업데이트는 15-20분 소요됩니다.
