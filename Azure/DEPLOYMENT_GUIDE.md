# AWS-Azure 멀티 클라우드 DR 전략 1번 배포 가이드

## 전략 개요

**Active-Standby with Azure as DR**

- **Primary**: AWS (Seoul, Tokyo) - Active
- **DR**: Azure (Korea Central) - Standby
- **데이터 복제**: Aurora → Azure MySQL (DMS 또는 Binlog)
- **Failover**: Route53 Health Check 기반 자동/수동

## 배포 순서

### Phase 1: Azure DR 환경 구축 (약 20분)

```bash
# 1. Azure 디렉토리로 이동
cd C:\Users\qkreh\OneDrive\Desktop\CheonSangYeon\CheonSangYeon\Azure

# 2. Terraform 초기화
terraform init

# 3. terraform.tfvars 파일 생성
cp terraform.tfvars.example terraform.tfvars

# 4. 필수 변수 편집
notepad terraform.tfvars
```

**terraform.tfvars 설정 예시:**
```hcl
# MySQL 비밀번호 (강력한 비밀번호 설정)
mysql_admin_password = "YourStrongPassword123!@#"

# 웹앱 이름 (글로벌 고유)
web_app_name = "webapp-dr-cheonsangyeon"

# 스토리지 계정 이름 (글로벌 고유, 소문자/숫자만)
storage_account_name = "stdrcheonsy001"

# 알림 이메일
alert_email = "your-email@example.com"

# VPN 공유 키 (32자 이상 권장)
vpn_shared_key = "YourSuperSecureVPNSharedKey12345678"
```

```bash
# 5. Azure 배포 (약 15-20분 소요)
terraform apply -auto-approve

# 6. Azure VPN Gateway Public IP 확인 및 저장
terraform output vpn_gateway_public_ip
# 출력 예시: 20.249.xxx.xxx
```

### Phase 2: AWS VPN 연결 설정 (약 5분)

```bash
# 1. Seoul 디렉토리로 이동
cd C:\Users\qkreh\OneDrive\Desktop\CheonSangYeon\CheonSangYeon\Seoul

# 2. Azure VPN 정보를 환경변수로 설정
$env:TF_VAR_enable_azure_dr = "true"
$env:TF_VAR_azure_vpn_gateway_ip = "20.249.xxx.xxx"  # Azure에서 가져온 IP
$env:TF_VAR_azure_vpn_shared_key = "YourSuperSecureVPNSharedKey12345678"

# 3. Terraform apply로 VPN 연결 생성
terraform apply -auto-approve

# 4. AWS VPN Tunnel 주소 확인
terraform output azure_vpn_tunnel_addresses
```

### Phase 3: Azure VPN 연결 완성 (약 5분)

```bash
# 1. AWS VPN Tunnel 1 주소 복사
# 예시: 13.209.xxx.xxx

# 2. Azure 디렉토리로 돌아가기
cd C:\Users\qkreh\OneDrive\Desktop\CheonSangYeon\CheonSangYeon\Azure

# 3. terraform.tfvars에 AWS VPN 정보 추가
notepad terraform.tfvars
```

**terraform.tfvars에 추가:**
```hcl
# AWS VPN 정보
aws_vpn_gateway_ip      = "13.209.xxx.xxx"  # Seoul에서 가져온 Tunnel 1 IP
aws_bgp_peering_address = "169.254.21.1"    # AWS BGP 주소 (VPN 설정에서 확인)
```

```bash
# 4. Azure VPN 재배포
terraform apply -auto-approve

# 5. VPN 연결 상태 확인 (약 2-3분 후)
az network vpn-connection show \
  --name aws-azure-vpn-connection \
  --resource-group rg-dr-multicloud \
  --query connectionStatus
# 출력: "Connected"가 나오면 성공
```

### Phase 4: 데이터 복제 설정 (약 10분)

#### 옵션 A: AWS DMS 사용 (권장)

```bash
# 1. Azure MySQL FQDN 확인
cd Azure
terraform output mysql_server_fqdn

# 2. DMS Target Endpoint 생성
aws dms create-endpoint \
  --endpoint-identifier azure-mysql-target \
  --endpoint-type target \
  --engine-name mysql \
  --server-name <AZURE_MYSQL_FQDN> \
  --port 3306 \
  --username sqladmin \
  --password <MYSQL_PASSWORD> \
  --database-name webapp_db \
  --region ap-northeast-2

# 3. DMS Replication Task 생성
aws dms create-replication-task \
  --replication-task-identifier aurora-to-azure-dr \
  --source-endpoint-arn <AURORA_SOURCE_ARN> \
  --target-endpoint-arn <AZURE_ENDPOINT_ARN> \
  --replication-instance-arn <REPLICATION_INSTANCE_ARN> \
  --migration-type full-load-and-cdc \
  --table-mappings '{"rules":[{"rule-type":"selection","rule-id":"1","rule-name":"1","object-locator":{"schema-name":"%","table-name":"%"},"rule-action":"include"}]}' \
  --region ap-northeast-2

# 4. Task 시작
aws dms start-replication-task \
  --replication-task-arn <TASK_ARN> \
  --start-replication-task-type start-replication \
  --region ap-northeast-2
```

#### 옵션 B: Binlog 복제 (수동)

```bash
# Aurora에서 binlog 활성화 후 Azure MySQL에서 복제 설정
# (상세 가이드는 Azure README.md 참조)
```

### Phase 5: Route53 Failover 설정 (약 5분)

```bash
# 1. Azure App Service 호스트명 확인
cd Azure
terraform output web_app_default_hostname

# 2. Route53 Health Check ID 확인
terraform output route53_health_check_id

# 3. Route53에 Failover 레코드 추가
cd ..\global\route53

# failover-secondary.json 생성
```

**failover-secondary.json 예시:**
```json
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "www.yourdomain.com",
      "Type": "CNAME",
      "SetIdentifier": "Azure-DR-Secondary",
      "Failover": "SECONDARY",
      "TTL": 60,
      "ResourceRecords": [{"Value": "webapp-dr-cheonsangyeon.azurewebsites.net"}],
      "HealthCheckId": "<HEALTH_CHECK_ID>"
    }
  }]
}
```

```bash
# Route53 레코드 생성
aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_HOSTED_ZONE_ID> \
  --change-batch file://failover-secondary.json \
  --region ap-northeast-2
```

### Phase 6: 테스트 및 검증 (약 10분)

```bash
# 1. VPN 연결 테스트
# AWS에서
aws ec2 describe-vpn-connections \
  --vpn-connection-ids <VPN_ID> \
  --region ap-northeast-2 \
  --query 'VpnConnections[0].VgwTelemetry'

# Azure에서
az network vpn-connection show \
  --name aws-azure-vpn-connection \
  --resource-group rg-dr-multicloud

# 2. 데이터 복제 상태 확인
aws dms describe-replication-tasks \
  --filters Name=replication-task-arn,Values=<TASK_ARN> \
  --region ap-northeast-2

# 3. Azure App Service 접속 테스트
curl -I https://<AZURE_APP_SERVICE_HOSTNAME>

# 4. Route53 Health Check 상태
aws route53 get-health-check-status \
  --health-check-id <HEALTH_CHECK_ID> \
  --region ap-northeast-2

# 5. DNS Failover 테스트 (주의: 트래픽 영향)
# AWS Primary를 일시 중지하고 Azure로 failover되는지 확인
```

## Failover 시나리오

### 자동 Failover

1. **AWS Primary 장애 감지** (Route53 Health Check)
   - 3회 연속 실패 시 자동 전환
   - 약 90초 소요 (30초 간격 × 3회)

2. **DNS 전환**
   - Route53이 자동으로 Azure DR로 트래픽 라우팅
   - TTL 60초 후 모든 사용자가 Azure로 접속

3. **모니터링**
   - CloudWatch Alarm 트리거
   - 이메일 알림 수신

### 수동 Failover

```bash
# 1. Azure DR 상태 확인
cd Azure
terraform output dr_status

# 2. Route53 DNS 수동 변경
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "www.yourdomain.com",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [{"Value": "<AZURE_APP_SERVICE_HOSTNAME>"}]
      }
    }]
  }' \
  --region ap-northeast-2

# 3. 트래픽 전환 확인
nslookup www.yourdomain.com
```

### Rollback (AWS 복구)

```bash
# 1. AWS 리전 복구 확인
aws elasticbeanstalk describe-environment-health \
  --environment-name seoul-webapp-env \
  --attribute-names All \
  --region ap-northeast-2

# 2. Route53 DNS 복구
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch file://failback-to-aws.json \
  --region ap-northeast-2

# 3. 데이터 역동기화 (필요 시)
# Azure → Aurora로 변경된 데이터 동기화
```

## 비용 추정

### Azure DR 환경 (월간)
- App Service (P1v3): ~$150
- MySQL Flexible Server (Zone-Redundant): ~$200
- VPN Gateway (VpnGw2): ~$300
- Storage (GRS): ~$50
- 데이터 전송: ~$100
- **소계: ~$800/월**

### AWS 추가 비용
- VPN Connection: ~$36/월
- DMS Replication: ~$100/월
- Route53 Health Check: ~$1/월
- **소계: ~$137/월**

**전체 DR 비용: ~$937/월**

## 유지보수 체크리스트

### 일일 점검
- [ ] VPN 연결 상태 확인
- [ ] Route53 Health Check 상태
- [ ] DMS 복제 지연 확인

### 주간 점검
- [ ] Azure App Service 성능 확인
- [ ] Azure MySQL 백업 상태
- [ ] 비용 사용량 검토

### 월간 점검
- [ ] DR 환경 접속 테스트
- [ ] 데이터 정합성 검증
- [ ] 보안 패치 업데이트

### 분기 점검
- [ ] **Failover 드릴 수행**
- [ ] 복구 시간 목표 (RTO) 검증
- [ ] 복구 시점 목표 (RPO) 검증
- [ ] DR 문서 업데이트

## 트러블슈팅

### VPN 연결 안됨

```bash
# AWS 측 확인
aws ec2 describe-vpn-connections --vpn-connection-ids <VPN_ID> --region ap-northeast-2

# Azure 측 확인
az network vpn-connection show --name aws-azure-vpn-connection --resource-group rg-dr-multicloud

# BGP 상태 확인
az network vnet-gateway show --name vpngw-dr-multicloud --resource-group rg-dr-multicloud --query bgpSettings
```

### 데이터 복제 지연

```bash
# DMS Task 상태
aws dms describe-replication-tasks --region ap-northeast-2

# 복제 지연 확인
aws dms describe-table-statistics --replication-task-arn <TASK_ARN> --region ap-northeast-2
```

### Azure App Service 접속 불가

```bash
# App Service 상태
az webapp show --name <WEB_APP_NAME> --resource-group rg-dr-multicloud

# 로그 확인
az webapp log tail --name <WEB_APP_NAME> --resource-group rg-dr-multicloud

# 재시작
az webapp restart --name <WEB_APP_NAME> --resource-group rg-dr-multicloud
```

## 보안 권장사항

1. **VPN 공유 키**: 32자 이상, 정기적 변경 (6개월)
2. **MySQL 비밀번호**: Azure Key Vault에 저장
3. **NSG 규칙**: 최소 권한 원칙
4. **Private Endpoint**: Production 환경에서는 Private Endpoint 사용 권장
5. **Azure AD 통합**: App Service에 Azure AD 인증 추가

## 다음 단계

DR 환경 구축 완료 후:
1. **모니터링 대시보드** 구성 (Azure Monitor + CloudWatch)
2. **알림 규칙** 세부 설정
3. **자동화 스크립트** 작성 (Failover/Rollback)
4. **DR 운영 매뉴얼** 작성
5. **정기 DR 훈련** 계획 수립

## 지원

문제 발생 시:
- Azure Portal: https://portal.azure.com
- AWS Console: https://console.aws.amazon.com
- Terraform 로그: `terraform apply -debug`
