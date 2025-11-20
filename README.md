<<<<<<< HEAD
# AWS Multi-Region Infrastructure with Transit Gateway

Seoul과 Tokyo 리전에 걸친 AWS 멀티 리전 인프라를 Terraform으로 관리합니다.

## 프로젝트 구조

```
CheonSangYeon/
├── global/                      # 글로벌 공유 리소스
│   ├── s3/                      # S3 백엔드 및 공유 버킷
│   ├── vpc/                     # 모든 VPC (Seoul AWS, Seoul IDC, Tokyo AWS, Tokyo IDC)
│   ├── aurora/                  # Aurora Global Database
│   ├── dms/                     # DMS 마이그레이션 (비활성화)
│   └── tgw-peering/             # Transit Gateway Peering
├── Seoul/                       # Seoul 리전 리소스
│   ├── main.tf                  # Beanstalk, Transit Gateway, VPN
│   ├── variables.tf
│   └── outputs.tf
└── Tokyo/                       # Tokyo 리전 리소스
    ├── main.tf                  # Beanstalk, Transit Gateway
    ├── variables.tf
    └── outputs.tf
```

## 인프라 구성

### VPC 아키텍처
- **Seoul AWS VPC** (20.0.0.0/16) - vpc-0ed96f16d7a1c201b
- **Seoul IDC VPC** (10.0.0.0/16) - vpc-0d31886e9f4dc578c
- **Tokyo AWS VPC** (40.0.0.0/16) - vpc-04aaeab19ae7b6fb0
- **Tokyo IDC VPC** (30.0.0.0/16) - vpc-0ab7dcbb86c69455d

### Transit Gateway
- **Seoul TGW**: tgw-00aa475a8ec145dc4
  - Seoul AWS VPC 연결
  - Seoul IDC VPC 연결 (VPN)
  - Tokyo TGW Peering
- **Tokyo TGW**: tgw-0e65a88096c497691
  - Tokyo AWS VPC 연결
  - Tokyo IDC VPC 연결
  - Seoul TGW Peering

### Aurora Global Database
- **Primary (Seoul)**: 1 Writer + 1 Reader (db.r5.large)
- **Secondary (Tokyo)**: 1 Reader (db.r5.large)
- **Engine**: Aurora MySQL 8.0
- **비용**: 월 ~$627 (이전 대비 40% 절감)

### Elastic Beanstalk
- **Seoul**: seoul-webapp-env (Python 3.11)
  - URL: http://seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com
  - ELB: 퍼블릭 서브넷, EC2: 프라이빗 서브넷
- **Tokyo**: tokyo-webapp-env (Python 3.11)

## 배포 순서

### 1. S3 백엔드 생성
```bash
cd global/s3
terraform init
terraform apply
```

### 2. VPC 인프라 배포
```bash
cd global/vpc
terraform init -backend-config="bucket=YOUR_BUCKET_NAME"
terraform apply
```

출력:
- Seoul VPC: vpc-0ed96f16d7a1c201b
- Seoul IDC VPC: vpc-0d31886e9f4dc578c
- Tokyo VPC: vpc-04aaeab19ae7b6fb0
- Tokyo IDC VPC: vpc-0ab7dcbb86c69455d

### 3. Aurora Global Database 배포
```bash
cd global/aurora
terraform init -backend-config=backend.tfvars
terraform apply
```

출력:
- Seoul Writer Endpoint
- Seoul Reader Endpoint
- Tokyo Reader Endpoint

### 4. Seoul 리전 배포
```bash
cd Seoul
terraform init
terraform apply
```

출력:
- Transit Gateway ID: tgw-00aa475a8ec145dc4
- VPN Connection ID: vpn-089edd593ccea148e
- Beanstalk CNAME: seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com

### 5. Tokyo 리전 배포
```bash
cd Tokyo
terraform init
terraform apply
```

### 6. Transit Gateway Peering 설정
```bash
cd global/tgw-peering
terraform init
terraform apply
```

### 7. (선택) DMS 마이그레이션
> ⚠️ 현재 DMS는 Terraform state에서 제거되어 비활성화 상태입니다.

```bash
cd global/dms
terraform init
terraform apply
```

## 네트워크 통신

### Seoul ↔ Tokyo (리전 간)
- Transit Gateway Peering을 통한 통신
- Seoul (20.0.0.0/16, 10.0.0.0/16) ↔ Tokyo (40.0.0.0/16, 30.0.0.0/16)

### Seoul AWS ↔ Seoul IDC
- Site-to-Site VPN (vpn-089edd593ccea148e)
- Seoul TGW를 통한 라우팅

### 인터넷 접속
- Beanstalk: Internet Gateway → ELB (퍼블릭) → NAT Gateway → EC2 (프라이빗)
- IDC: Internet Gateway 직접 연결

## 주요 변경 사항

### 2024-01 최근 업데이트
1. **Aurora 인스턴스 최적화**
   - 리더 인스턴스: 각 리전당 2대 → 1대 축소
   - 인스턴스 타입: db.r6g.large → db.r5.large
   - 비용 절감: 월 $409 (40% 감소)

2. **Seoul IDC VPC 통합**
   - Seoul IDC VPC를 global/vpc로 통합
   - VPN 연결 자동화

3. **Beanstalk ELB 설정 개선**
   - ELB를 퍼블릭 서브넷에 배치
   - EC2는 프라이빗 서브넷 유지 (보안 강화)

4. **DMS 비활성화**
   - Terraform state에서 제거
   - 필요 시 재활성화 가능

## 접속 정보

### Seoul Beanstalk
```bash
# HTTP 접속
curl http://seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com
```

### Aurora Database
```bash
# Seoul Writer (읽기/쓰기)
mysql -h aurora-global-seoul-cluster.cluster-xxxxx.ap-northeast-2.rds.amazonaws.com -u admin -p

# Seoul Reader (읽기 전용)
mysql -h aurora-global-seoul-cluster.cluster-ro-xxxxx.ap-northeast-2.rds.amazonaws.com -u admin -p

# Tokyo Reader (읽기 전용)
mysql -h aurora-global-tokyo-cluster.cluster-ro-xxxxx.ap-northeast-1.rds.amazonaws.com -u admin -p
```

## 비용 예상 (월)

| 항목 | 수량 | 단가 | 월 비용 |
|------|------|------|---------|
| Aurora DB (db.r5.large) | 3개 | $0.29/시간 | $627 |
| Beanstalk (t3.medium) | 4개 | $0.042/시간 | $121 |
| NAT Gateway | 4개 | $32/월 | $128 |
| Transit Gateway | 2개 | $36/월 | $72 |
| VPN Connection | 1개 | $36/월 | $36 |
| **총계** | | | **$984** |

## 트러블슈팅

### Beanstalk 웹 접속 불가
```bash
# ELB 상태 확인
aws elbv2 describe-load-balancers --region ap-northeast-2

# Target Health 확인
aws elbv2 describe-target-health --target-group-arn <TG_ARN>
```

### VPN 연결 끊김
```bash
# VPN 상태 확인
aws ec2 describe-vpn-connections --vpn-connection-ids vpn-089edd593ccea148e

# StrongSwan 재시작 (IDC CGW에서)
ssh -i your-key.pem ec2-user@<IDC_CGW_IP>
sudo strongswan restart
```

### Aurora 연결 실패
```bash
# 보안 그룹 확인
aws ec2 describe-security-groups --group-ids <SG_ID>

# 엔드포인트 확인
cd global/aurora
terraform output
```

## 주의사항

- EC2 키 페어가 각 리전에 미리 생성되어 있어야 합니다
- S3 백엔드를 먼저 생성해야 합니다
- VPC 배포 후 Transit Gateway ID 확인 필요
- Aurora 마스터 비밀번호는 AWS Secrets Manager로 관리 권장
- DMS는 현재 비활성화되어 있습니다 (필요 시 재활성화)
=======
# CheonSangYeon

## Remote state bootstrap & usage

Each Terraform stack in this repository is configured to use the shared remote
backend below. **Never check local state or plan files into git.**

- **S3 bucket:** `terraform-s3-cheonsangyeon`
- **Key prefixes:** `terraform/<stack>/terraform.tfstate` (for example,
  `terraform/seoul/terraform.tfstate`)
- **Region:** `ap-northeast-2`
- **DynamoDB table for state locking:** `terraform-Dynamo-CheonSangYeon`

To bootstrap the backend for a new contributor or workstation:

1. Ensure AWS credentials with access to the S3 bucket and DynamoDB table are
   configured (e.g., using `aws configure sso` or environment variables).
2. Run `terraform init -backend-config="region=ap-northeast-2"` inside the
   desired stack directory (`Seoul`, `Tokyo`, `global/...`). Terraform will read
   the backend definition from `main.tf` and reuse the shared state bucket and
   lock table.
3. If a new stack folder is introduced, provision its backend objects first:
   create the `terraform-s3-cheonsangyeon` bucket (versioned, encrypted) and the
   `terraform-Dynamo-CheonSangYeon` table with `LockID` as the primary key, then
   add an appropriate `key` prefix inside the stack's `terraform { backend "s3" }
   block.

Because state now lives exclusively in S3, local artifacts such as
`terraform.tfstate`, `*.tfstate.backup`, `*.tfplan`, crash logs, and
`current-state.json` are ignored by git to prevent accidental commits.

## Security note

Sensitive identifiers (Elastic IPs, Transit Gateways, IAM roles, etc.) were
previously exposed via committed state files. After removing the files from the
repository, rotate or recreate those resources via AWS as needed to invalidate
any information that might have been captured while they were public.
>>>>>>> 0a53650c55c50f5f8f315c7eef4f600ba8e87759
