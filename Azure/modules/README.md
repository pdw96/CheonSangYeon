# Azure Modular Architecture README

## 개요
Azure 모듈을 AWS 연동 포인트별로 분리하여 관리합니다.

## 모듈 구조

### 1. `modules/dms-integration/`
**목적**: AWS DMS와 연동되는 Azure MySQL Flexible Server 관리

**주요 리소스**:
- Azure MySQL Flexible Server (DMS 타겟)
- Private DNS Zone
- Firewall Rules (AWS VPN 접근)
- Database 생성

**사용 사례**:
- AWS Aurora → Azure MySQL 데이터 복제
- DMS 마이그레이션 타겟 데이터베이스
- Cross-cloud 데이터 동기화

### 2. `modules/ecr-appservice/`
**목적**: AWS ECR 컨테이너를 사용하는 Azure App Service 관리

**주요 리소스**:
- App Service Plan
- Linux Web App with ECR container
- VNet Integration
- Custom Domain (선택사항)

**사용 사례**:
- AWS ECR 이미지를 Azure에서 실행
- DR 환경에서 동일한 컨테이너 이미지 사용
- Multi-cloud 애플리케이션 배포

**ECR 인증**:
- ECR 토큰은 12시간 후 만료
- `aws ecr get-login-password` 명령으로 갱신 필요

### 3. `modules/route53-healthcheck/`
**목적**: Azure 엔드포인트에 대한 AWS Route53 헬스 체크 및 모니터링

**주요 리소스**:
- Route53 Health Check
- CloudWatch Alarm (Unhealthy)
- CloudWatch Alarm (High Latency, 선택사항)

**사용 사례**:
- Azure DR 엔드포인트 상태 모니터링
- Failover 자동화를 위한 헬스 체크
- Cross-cloud 모니터링

### 4. `modules/aws-dms-migration/`
**목적**: Aurora MySQL → Azure MySQL 자동 마이그레이션

**주요 리소스**:
- AWS DMS Source Endpoint (Aurora)
- AWS DMS Target Endpoint (Azure MySQL)
- DMS Replication Task
- CloudWatch Log Group
- Auto-start provisioner (선택사항)

**사용 사례**:
- Azure 배포 시 자동으로 Aurora 데이터 복제
- 스키마 변환 (globaldb → webapp_db)
- Full Load 또는 CDC 마이그레이션

**중요 사항**:
- Azure MySQL이 먼저 배포되어야 함
- VPN 연결이 활성화되어 있어야 함
- global/dms의 Replication Instance 필요

### 5. `modules/route53-records/`
**목적**: Azure 엔드포인트에 대한 Route53 DNS 레코드 자동 생성

**주요 리소스**:
- Route53 CNAME Record (azure.domain.com)
- Route53 Failover Records (선택사항)
- TXT Records (검증용, 선택사항)

**사용 사례**:
- Azure App Service에 대한 DNS 레코드 자동 생성
- Failover 라우팅 설정 (Primary: CloudFront, Secondary: Azure)
- 도메인 검증 레코드 추가

**중요 사항**:
- global/route53이 먼저 배포되어 있어야 함
- 도메인이 등록되어 있어야 함

## 사용 방법

### 기본 배포
```bash
cd Azure
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### DMS 자동 마이그레이션 활성화
```hcl
# terraform.tfvars
enable_auto_dms_migration = true
```

배포 시 자동으로:
1. Azure MySQL 생성
2. DMS 엔드포인트 생성 (Aurora → Azure)
3. 마이그레이션 태스크 생성
4. 태스크 자동 시작 (enable_auto_dms_migration = true인 경우)

## 사용 방법

### 기본 배포
```bash
cd Azure
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 모듈별 독립 배포

#### DMS Integration만 배포
```hcl
module "dms_only" {
  source = "./modules/dms-integration"
  
  resource_group_name = "rg-dr-test"
  location            = "koreacentral"
  mysql_server_name   = "mysql-dms-test"
  # ... other variables
}
```

#### ECR App Service만 배포
```hcl
module "app_only" {
  source = "./modules/ecr-appservice"
  
  resource_group_name = "rg-dr-test"
  location            = "koreacentral"
  web_app_name        = "webapp-ecr-test"
  ecr_registry_url    = "123456.dkr.ecr.ap-northeast-2.amazonaws.com"
  # ... other variables
}
```

## 주요 변수

### DMS Integration
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `mysql_server_name` | MySQL 서버 이름 | - |
| `mysql_sku_name` | MySQL SKU | `B_Standard_B1ms` |
| `aws_vpc_cidr_start` | AWS VPC CIDR 시작 | `20.0.0.0` |

### ECR App Service
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `ecr_registry_url` | ECR 레지스트리 URL | - |
| `ecr_image_name` | ECR 이미지:태그 | - |
| `ecr_password` | ECR 토큰 | - |
| `database_connection_enabled` | DB 연결 활성화 | `false` |

### Route53 Health Check
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `endpoint_fqdn` | 모니터링할 FQDN | - |
| `health_check_path` | 헬스 체크 경로 | `/health` |
| `enable_latency_alarm` | 레이턴시 알람 | `false` |

### AWS DMS Migration
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `azure_mysql_endpoint` | Azure MySQL FQDN | - |
| `source_database_name` | 소스 DB 이름 | `globaldb` |
| `target_database_name` | 타겟 DB 이름 | - |
| `migration_type` | 마이그레이션 타입 | `full-load` |
| `auto_start_migration` | 자동 시작 | `false` |

### Route53 Records
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `create_azure_dns_record` | DNS 레코드 생성 | `true` |
| `subdomain_name` | 서브도메인 | `azure.domain.com` |
| `enable_failover_routing` | Failover 라우팅 | `false` |

## 파일 구조
```
Azure/
├── main-modular.tf           # 모듈 기반 메인 설정
├── outputs-modular.tf        # 모듈 기반 출력
├── variables.tf              # 변수 정의
├── terraform.tfvars          # 변수 값
└── modules/
    ├── dms-integration/      # Azure MySQL (DMS 타겟)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ecr-appservice/       # ECR 컨테이너 App Service
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── route53-healthcheck/  # Route53 헬스 체크
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── aws-dms-migration/    # Aurora → Azure 마이그레이션
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
    └── route53-records/      # Route53 DNS 레코드
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## 마이그레이션 워크플로우

### Aurora → Azure MySQL 자동 마이그레이션 + Route53 자동 설정

1. **사전 요구사항**
```bash
# global/route53 먼저 배포 (Hosted Zone 생성)
cd global/route53
terraform apply

# global/dms 배포 (Replication Instance 생성)
cd global/dms
terraform apply

# VPN 연결 확인
aws ec2 describe-vpn-connections --region ap-northeast-2
```

2. **Azure 배포 (자동 통합)**
```bash
cd Azure
terraform apply \
  -var="enable_auto_dms_migration=true" \
  -var="create_azure_dns_record=true" \
  -var="enable_failover_routing=true"
```

자동으로 수행되는 작업:
- ✅ Azure MySQL Flexible Server 생성
- ✅ Azure App Service (ECR 컨테이너) 배포
- ✅ DMS Source Endpoint (Aurora) 생성
- ✅ DMS Target Endpoint (Azure MySQL) 생성
- ✅ DMS Replication Task 생성 및 시작
- ✅ Route53 DNS 레코드 생성 (azure.domain.com)
- ✅ Route53 Health Check 생성
- ✅ (선택) Failover 라우팅 설정

3. **배포 확인**
```bash
# DNS 레코드 확인
terraform output azure_dns_record
# 출력: azure.cloudupcon.com

# DMS 마이그레이션 상태
terraform output dms_migration_status

# App Service URL
terraform output web_app_url
```

4. **접속 테스트**
```bash
# Azure 직접 접속
curl https://$(terraform output -raw azure_dns_record)

# Failover 엔드포인트 (활성화된 경우)
curl https://app.cloudupcon.com
```

3. **마이그레이션 모니터링**
```bash
# 태스크 상태 확인
aws dms describe-replication-tasks \
  --filters Name=replication-task-arn,Values=<task-arn>

# CloudWatch Logs
aws logs tail /aws/dms/tasks/aurora-to-azure-migration-task --follow

# Azure MySQL 데이터 확인
mysql -h <azure-mysql-fqdn> -u sqladmin -p webapp_db
```

## 파일 구조

### 기존 main.tf → main-modular.tf 전환

1. **상태 백업**
```bash
terraform state pull > backup.tfstate
```

2. **리소스 이동** (예: MySQL)
```bash
terraform state mv \
  azurerm_mysql_flexible_server.dr \
  module.dms_integration.azurerm_mysql_flexible_server.dms_target
```

3. **검증**
```bash
terraform plan  # No changes expected
```

## 모범 사례

1. **모듈 버전 관리**: Git 태그로 모듈 버전 관리
2. **변수 검증**: variables.tf에 validation 블록 추가
3. **출력 문서화**: 각 모듈의 outputs.tf에 명확한 설명 추가
4. **태그 표준화**: 모든 리소스에 일관된 태그 적용

## 문제 해결

### DMS 마이그레이션 실패
1. **VPN 연결 확인**
```bash
# Azure VPN Gateway 상태
az network vnet-gateway show -g rg-dr-multicloud -n vpngw-dr-multicloud

# AWS VPN 연결 상태
aws ec2 describe-vpn-connections --region ap-northeast-2
```

2. **네트워크 연결 테스트**
```bash
# DMS Replication Instance에서 Azure MySQL 접근 가능 여부
# (AWS Console의 Test Connection 기능 사용)
```

3. **MySQL 방화벽 확인**
```bash
# Azure MySQL 방화벽 규칙 확인
az mysql flexible-server firewall-rule list \
  -g rg-dr-multicloud -n mysql-dr-multicloud
```

### 마이그레이션 수동 시작
```bash
# 자동 시작이 실패한 경우
aws dms start-replication-task \
  --replication-task-arn <task-arn> \
  --start-replication-task-type start-replication \
  --region ap-northeast-2
```

### ECR 인증 만료
```bash
# 새 토큰 생성
aws ecr get-login-password --region ap-northeast-2

# terraform.tfvars 업데이트
ecr_password = "<new-token>"

# App Service 재배포
terraform apply -target=module.ecr_appservice
```

### DMS 연결 실패
1. VPN 연결 상태 확인
2. MySQL 방화벽 규칙 확인
3. AWS VPC CIDR 범위 확인

## 배포 순서

1. **Global Route53** (Hosted Zone)
```bash
cd global/route53
terraform apply
```

2. **Global DMS** (Replication Instance)
```bash
cd global/dms
terraform apply
```

3. **Azure 인프라** (모든 것 자동 통합)
```bash
cd Azure
terraform apply \
  -var="enable_auto_dms_migration=true" \
  -var="create_azure_dns_record=true"
```

4. **검증**
```bash
# Route53 DNS 레코드
dig azure.cloudupcon.com

# DMS 마이그레이션 상태
terraform output dms_migration_status

# Azure MySQL 데이터 확인
mysql -h <azure-mysql-fqdn> -u sqladmin -p webapp_db

# App Service 동작 확인
curl https://azure.cloudupcon.com
```

## DNS 레코드 구조

배포 후 생성되는 DNS 레코드:

```
cloudupcon.com              → CloudFront (Primary)
www.cloudupcon.com          → CloudFront
seoul.cloudupcon.com        → Seoul Beanstalk
tokyo.cloudupcon.com        → Tokyo Beanstalk
azure.cloudupcon.com        → Azure App Service (NEW)
app.cloudupcon.com          → Failover (Primary: CloudFront, Secondary: Azure) (선택)
```

## 참고 자료
- [Azure MySQL Flexible Server](https://learn.microsoft.com/azure/mysql/flexible-server/)
- [Azure App Service with Containers](https://learn.microsoft.com/azure/app-service/configure-custom-container)
- [AWS Route53 Health Checks](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)
