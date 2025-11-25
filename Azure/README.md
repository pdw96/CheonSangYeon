# Azure DR 환경 구성 가이드

## 개요

이 디렉토리는 AWS-Azure 멀티 클라우드 DR (Disaster Recovery) 전략 1번을 구현합니다:
**Active-Standby with Azure as DR**

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Primary Region                       │
│                         (ap-northeast-2)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │  Beanstalk   │────│    Aurora    │────│  CloudFront  │     │
│  │   (Active)   │    │   (Primary)  │    │    (CDN)     │     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
│         │                    │                    │             │
│         └────────────────────┼────────────────────┘             │
│                              │                                  │
│                    ┌─────────▼──────────┐                      │
│                    │  Transit Gateway   │                      │
│                    └─────────┬──────────┘                      │
│                              │                                  │
└──────────────────────────────┼──────────────────────────────────┘
                               │
                          VPN Tunnel
                        (Site-to-Site)
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                      Azure DR Region                             │
│                       (koreacentral)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │ App Service  │────│    MySQL     │────│   Storage    │     │
│  │  (Standby)   │    │  (Replica)   │    │  (Backup)    │     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
│         │                    │                    │             │
│         └────────────────────┼────────────────────┘             │
│                              │                                  │
│                    ┌─────────▼──────────┐                      │
│                    │   VPN Gateway      │                      │
│                    └────────────────────┘                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                               │
                    Route53 Health Check
                     (Automatic Failover)
```

## 주요 기능

### 1. Azure 인프라 구성
- **Virtual Network**: 50.0.0.0/16 (AWS와 겹치지 않는 범위)
- **MySQL Flexible Server**: Zone-Redundant HA 구성
- **App Service**: Premium v3 (VNet 통합)
- **Storage Account**: GRS (Geo-Redundant Storage)

### 2. AWS-Azure 연결
- **VPN Gateway**: Site-to-Site VPN with BGP
- **Transit Gateway**: AWS 측 VPN 연결
- **BGP Routing**: 동적 라우팅으로 자동 failover

### 3. 데이터 복제
- **Aurora → MySQL**: DMS 또는 Binlog 복제
- **S3 → Azure Blob**: 백업 및 정적 파일 동기화

### 4. 모니터링 및 알림
- **Route53 Health Check**: Azure 엔드포인트 모니터링
- **Azure Monitor**: 앱 및 DB 상태 모니터링
- **CloudWatch Alarms**: DR 헬스 체크 알림

## 배포 순서

### 1. 사전 준비

```bash
# Azure CLI 로그인
az login

# 구독 선택
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Terraform 초기화
cd Azure
terraform init
```

### 2. 변수 설정

```bash
# terraform.tfvars 파일 생성
cp terraform.tfvars.example terraform.tfvars

# 필수 변수 설정
vi terraform.tfvars
```

필수 변수:
- `mysql_admin_password`: MySQL 관리자 비밀번호
- `web_app_name`: 글로벌 고유 웹앱 이름
- `storage_account_name`: 글로벌 고유 스토리지 이름
- `alert_email`: 알림 수신 이메일

### 3. Azure 인프라 배포

```bash
# Plan 확인
terraform plan

# 배포 (약 15-20분 소요)
terraform apply -auto-approve
```

### 4. AWS VPN 연결 설정

Azure 배포 완료 후 출력되는 정보를 사용하여 AWS VPN 설정:

```bash
# Azure VPN Gateway 정보 확인
terraform output vpn_gateway_public_ip
terraform output vpn_gateway_bgp_asn
terraform output vpn_gateway_bgp_peering_address

# AWS에서 Customer Gateway 생성
aws ec2 create-customer-gateway \
  --type ipsec.1 \
  --public-ip <AZURE_VPN_GATEWAY_IP> \
  --bgp-asn <AZURE_BGP_ASN> \
  --tag-specifications 'ResourceType=customer-gateway,Tags=[{Key=Name,Value=azure-dr-cgw}]'

# AWS VPN Connection 생성
aws ec2 create-vpn-connection \
  --type ipsec.1 \
  --customer-gateway-id <CGW_ID> \
  --transit-gateway-id <TGW_ID> \
  --options TunnelOptions='[{TunnelInsideCidr=169.254.21.0/30,PreSharedKey=<STRONG_KEY>}]'
```

### 5. VPN 변수 업데이트 및 재배포

AWS VPN Connection 생성 후:

```bash
# terraform.tfvars에 AWS VPN 정보 추가
echo 'aws_vpn_gateway_ip = "13.209.xxx.xxx"' >> terraform.tfvars
echo 'aws_bgp_peering_address = "169.254.21.1"' >> terraform.tfvars
echo 'vpn_shared_key = "YourSharedKey"' >> terraform.tfvars

# 재배포
terraform apply -auto-approve
```

### 6. 데이터 복제 설정

#### Aurora → Azure MySQL 복제 (DMS 사용)

```bash
# AWS DMS Endpoint 생성 (Azure MySQL)
aws dms create-endpoint \
  --endpoint-identifier azure-mysql-target \
  --endpoint-type target \
  --engine-name mysql \
  --server-name <AZURE_MYSQL_FQDN> \
  --port 3306 \
  --username sqladmin \
  --password <MYSQL_PASSWORD> \
  --database-name webapp_db

# DMS Replication Task 생성
aws dms create-replication-task \
  --replication-task-identifier aurora-to-azure \
  --source-endpoint-arn <AURORA_ENDPOINT_ARN> \
  --target-endpoint-arn <AZURE_ENDPOINT_ARN> \
  --replication-instance-arn <REPLICATION_INSTANCE_ARN> \
  --migration-type full-load-and-cdc \
  --table-mappings file://table-mappings.json
```

#### S3 → Azure Blob 동기화

```bash
# AzCopy 사용
azcopy sync \
  "https://your-bucket.s3.amazonaws.com/" \
  "https://<STORAGE_ACCOUNT>.blob.core.windows.net/<CONTAINER>" \
  --recursive
```

### 7. Route53 Failover 설정

```bash
# Route53 Hosted Zone에 Failover 레코드 추가
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "www.yourdomain.com",
        "Type": "CNAME",
        "SetIdentifier": "Azure-DR",
        "Failover": "SECONDARY",
        "TTL": 60,
        "ResourceRecords": [{"Value": "<AZURE_APP_SERVICE_HOSTNAME>"}],
        "HealthCheckId": "<HEALTH_CHECK_ID>"
      }
    }]
  }'
```

## Failover 시나리오

### 자동 Failover (Route53 기반)

1. **AWS Primary 장애 감지**
   - Route53 Health Check가 AWS 엔드포인트 실패 감지 (3회 연속)
   - TTL 60초 후 자동으로 Azure DR로 트래픽 전환

2. **트래픽 전환**
   - DNS: www.yourdomain.com → Azure App Service
   - 사용자는 자동으로 Azure 환경으로 라우팅

3. **모니터링**
   - CloudWatch Alarm 트리거
   - Azure Monitor에서 증가한 트래픽 확인

### 수동 Failover

```bash
# 1. Azure DR 환경 상태 확인
terraform output dr_status

# 2. Route53 DNS 수동 변경
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch file://failover-to-azure.json

# 3. 데이터베이스 동기화 확인
# Azure Portal에서 MySQL 복제 지연 확인

# 4. 애플리케이션 로그 확인
az webapp log tail --name <WEB_APP_NAME> --resource-group <RG_NAME>
```

### Rollback (AWS로 복구)

```bash
# 1. AWS 리전 복구 확인
aws cloudwatch describe-alarms --alarm-names seoul-region-health

# 2. Route53 DNS 복구
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch file://failback-to-aws.json

# 3. 데이터 역동기화 (필요 시)
# Azure MySQL → Aurora로 변경된 데이터 동기화
```

## 비용 예상 (월간)

### Azure 리소스
- **App Service (P1v3)**: ~$150
- **MySQL Flexible Server (D2ds_v4, Zone-Redundant)**: ~$200
- **VPN Gateway (VpnGw2)**: ~$300
- **Storage Account (GRS)**: ~$50
- **데이터 전송**: ~$100
- **Total**: **~$800/월**

### AWS 추가 비용
- **VPN Connection**: ~$36/월
- **Transit Gateway Attachment**: ~$36/월
- **DMS Replication**: ~$100/월
- **Route53 Health Check**: ~$1/월
- **Total**: **~$173/월**

**전체 DR 환경 비용**: **~$973/월**

## 모니터링

### Azure Monitor

```bash
# App Service 메트릭 확인
az monitor metrics list \
  --resource <WEB_APP_ID> \
  --metric "HttpResponseTime" "Http5xx"

# MySQL 메트릭 확인
az monitor metrics list \
  --resource <MYSQL_SERVER_ID> \
  --metric "cpu_percent" "storage_percent"
```

### AWS CloudWatch

```bash
# Route53 Health Check 상태
aws route53 get-health-check-status \
  --health-check-id <HEALTH_CHECK_ID>

# VPN 연결 상태
aws ec2 describe-vpn-connections \
  --vpn-connection-ids <VPN_ID>
```

## 테스트

### DR 환경 테스트

```bash
# 1. Azure App Service 접속 테스트
curl -I https://<AZURE_APP_SERVICE_HOSTNAME>

# 2. Azure MySQL 연결 테스트
mysql -h <AZURE_MYSQL_FQDN> -u sqladmin -p webapp_db -e "SHOW TABLES;"

# 3. VPN 연결 테스트
az network vpn-connection show \
  --name aws-azure-vpn-connection \
  --resource-group <RG_NAME> \
  --query connectionStatus

# 4. 데이터 복제 지연 확인
# Azure MySQL에서 복제 상태 확인
SHOW SLAVE STATUS\G
```

### Failover 드릴

```bash
# 1. AWS Primary 일시 중지 (주의!)
aws elasticbeanstalk update-environment \
  --environment-name seoul-webapp-env \
  --option-settings Namespace=aws:elasticbeanstalk:command,OptionName=DeploymentPolicy,Value=AllAtOnce

# 2. Route53 Health Check 실패 대기 (약 90초)

# 3. Azure로 자동 failover 확인
nslookup www.yourdomain.com

# 4. Azure App Service 트래픽 확인
az monitor metrics list \
  --resource <WEB_APP_ID> \
  --metric "Requests"

# 5. AWS Primary 복구
aws elasticbeanstalk update-environment \
  --environment-name seoul-webapp-env \
  --option-settings Namespace=aws:elasticbeanstalk:command,OptionName=DeploymentPolicy,Value=Rolling
```

## 트러블슈팅

### VPN 연결 안됨

```bash
# Azure VPN 상태 확인
az network vpn-connection show \
  --name aws-azure-vpn-connection \
  --resource-group <RG_NAME>

# AWS VPN 상태 확인
aws ec2 describe-vpn-connections --vpn-connection-ids <VPN_ID>

# BGP 설정 확인
az network vnet-gateway show \
  --name <VPN_GATEWAY_NAME> \
  --resource-group <RG_NAME> \
  --query bgpSettings
```

### 데이터 복제 지연

```bash
# DMS 복제 상태 확인
aws dms describe-replication-tasks \
  --filters Name=replication-task-arn,Values=<TASK_ARN>

# Azure MySQL 복제 통계
az mysql flexible-server show \
  --name <MYSQL_SERVER_NAME> \
  --resource-group <RG_NAME>
```

### App Service 성능 문제

```bash
# 인스턴스 수 확인
az appservice plan show \
  --name <PLAN_NAME> \
  --resource-group <RG_NAME> \
  --query sku

# Scale out (필요 시)
az appservice plan update \
  --name <PLAN_NAME> \
  --resource-group <RG_NAME> \
  --number-of-workers 3
```

## 보안 권장사항

1. **VPN 공유 키**: 강력한 키 사용 (32자 이상)
2. **MySQL 비밀번호**: Azure Key Vault에 저장
3. **NSG 규칙**: 최소 권한 원칙 적용
4. **Private Endpoint**: 가능하면 Private Endpoint 사용
5. **Azure AD 인증**: App Service에 Azure AD 통합

## 유지보수

### 정기 작업

- **매일**: VPN 연결 상태 확인
- **매주**: 데이터 복제 지연 확인
- **매월**: DR 환경 접속 테스트
- **분기**: Failover 드릴 수행
- **반기**: 비용 최적화 검토

## 참고 자료

- [Azure Site Recovery](https://docs.microsoft.com/azure/site-recovery/)
- [AWS-Azure VPN](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
- [Azure MySQL Flexible Server](https://docs.microsoft.com/azure/mysql/flexible-server/)
- [AWS DMS](https://docs.aws.amazon.com/dms/)

## 지원

문제 발생 시:
1. Azure Portal에서 리소스 상태 확인
2. Terraform 로그 확인: `terraform apply -debug`
3. Azure Monitor 및 CloudWatch 로그 분석
