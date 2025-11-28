# ECR App Service Deployment

이 디렉토리는 AWS ECR 컨테이너 이미지를 사용하는 Azure App Service를 별도로 배포합니다.

## Prerequisites

1. **Azure DR 인프라 배포 완료**: `Azure/` 디렉토리에서 메인 인프라가 먼저 배포되어야 합니다.
2. **ECR 이미지**: AWS ECR에 컨테이너 이미지가 업로드되어 있어야 합니다.
3. **ECR 토큰**: AWS ECR 인증 토큰 필요 (12시간 유효)

## Quick Start

### 1. ECR 토큰 생성

```bash
# AWS ECR 로그인 토큰 생성
aws ecr get-login-password --region ap-northeast-2
```

### 2. 변수 설정

```bash
# terraform.tfvars 파일 생성
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars 파일 편집
# - ecr_password: 위에서 생성한 ECR 토큰
# - mysql_admin_password: Azure MySQL 관리자 비밀번호
```

### 3. 배포

```bash
# Terraform 초기화
terraform init

# 배포 계획 확인
terraform plan

# 배포 실행
terraform apply
```

## Architecture

```
Azure DR Infrastructure (이미 배포됨)
    ├── Resource Group
    ├── VNet
    ├── App Subnet
    └── MySQL Flexible Server

ECR App Service (별도 배포)
    ├── App Service Plan (B1)
    └── Linux Web App
        ├── Container: AWS ECR 이미지
        ├── VNet Integration → App Subnet
        └── Database Connection → Azure MySQL
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ecr_password` | ECR 인증 토큰 | `eyJwYXlsb2Fk...` |
| `mysql_admin_password` | MySQL 비밀번호 | `YourPassword123!` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ecr_registry_url` | `299145660695.dkr.ecr.ap-northeast-2.amazonaws.com` | ECR 레지스트리 URL |
| `ecr_image_name` | `seoul-portal-seoul-frontend:latest` | ECR 이미지:태그 |
| `web_app_name` | `webapp-dr-multicloud` | App Service 이름 |
| `app_service_sku` | `B1` | App Service Plan SKU |

## Outputs

배포 후 다음 정보가 출력됩니다:

- `web_app_url`: 웹앱 URL (https://webapp-dr-multicloud.azurewebsites.net)
- `web_app_default_hostname`: 호스트네임
- `outbound_ip_addresses`: Outbound IP 목록

## ECR Token Renewal

ECR 토큰은 **12시간 후 만료**되므로 주기적으로 갱신해야 합니다.

### 자동 갱신 (권장)

```bash
# ECR 토큰 갱신 및 App Service 업데이트
ECR_TOKEN=$(aws ecr get-login-password --region ap-northeast-2)

az webapp config appsettings set \
  --name webapp-dr-multicloud \
  --resource-group rg-dr-multicloud \
  --settings DOCKER_REGISTRY_SERVER_PASSWORD="$ECR_TOKEN"

# App Service 재시작
az webapp restart \
  --name webapp-dr-multicloud \
  --resource-group rg-dr-multicloud
```

### Terraform으로 갱신

```bash
# terraform.tfvars에서 ecr_password 업데이트
terraform apply -auto-approve
```

## Troubleshooting

### 1. ECR 이미지를 Pull할 수 없음

```bash
# ECR 토큰이 만료되었는지 확인
# 새 토큰으로 업데이트
aws ecr get-login-password --region ap-northeast-2
```

### 2. 데이터베이스 연결 실패

```bash
# MySQL 방화벽 규칙 확인
az mysql flexible-server firewall-rule list \
  --resource-group rg-dr-multicloud \
  --name mysql-dr-multicloud

# App Service Outbound IP 확인
terraform output outbound_ip_addresses
```

### 3. App Service가 시작되지 않음

```bash
# 로그 확인
az webapp log tail \
  --name webapp-dr-multicloud \
  --resource-group rg-dr-multicloud

# 환경변수 확인
az webapp config appsettings list \
  --name webapp-dr-multicloud \
  --resource-group rg-dr-multicloud
```

## Cleanup

```bash
# ECR App Service만 삭제
terraform destroy

# 참고: Azure DR 인프라는 유지됨
```

## Integration with Main Infrastructure

배포 후 메인 인프라(`Azure/main.tf`)에서 다음 주석을 해제하여 통합:

1. **Route53 Health Check** (line ~300):
   ```hcl
   # endpoint_fqdn을 실제 값으로 업데이트
   ```

2. **Azure Monitor Alert** (line ~587):
   ```hcl
   # scopes를 실제 Web App ID로 업데이트
   ```

## Cost Estimation

- **App Service Plan (B1)**: ~$13/month
- **App Service**: Plan에 포함
- **Data Transfer**: Outbound 데이터 비용 별도

## Security Notes

1. **ECR 토큰 보안**:
   - terraform.tfvars를 .gitignore에 추가
   - 환경변수 사용 권장: `TF_VAR_ecr_password`

2. **MySQL 비밀번호**:
   - 강력한 비밀번호 사용
   - Azure Key Vault 통합 권장

3. **VNet Integration**:
   - Private Endpoint 사용 고려
   - NSG 규칙 검토

## References

- [Azure App Service](https://learn.microsoft.com/azure/app-service/)
- [AWS ECR](https://docs.aws.amazon.com/ecr/)
- [ECR Token](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html)
