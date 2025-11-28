# AWS Multi-Region Hybrid Cloud Infrastructure

> Seoul과 Tokyo 리전을 Transit Gateway로 연결하고, 각 리전에 IDC 환경을 VPN으로 연결한 Hybrid Cloud 인프라입니다.  
> Aurora Global Database, CloudFront, Route 53을 통해 글로벌 서비스를 제공합니다.

---

## 📋 목차

- [프로젝트 개요](#프로젝트-개요)
- [아키텍처 다이어그램](#아키텍처-다이어그램)
- [프로젝트 구조](#프로젝트-구조)
- [모듈 상세 설명](#모듈-상세-설명)
- [배포 가이드](#배포-가이드)
- [현재 인프라 상태](#현재-인프라-상태)
- [비용 예상](#비용-예상)
- [트러블슈팅](#트러블슈팅)
- [다음 단계](#다음-단계)

---

## 프로젝트 개요

### 주요 특징

✅ **Multi-Region**: Seoul (Primary) + Tokyo (Secondary)  
✅ **Hybrid Cloud**: AWS VPC + On-Premise IDC (VPN 연결)  
✅ **Global Database**: Aurora Global Database (RPO < 1초)  
✅ **Global CDN**: CloudFront + Route 53 (도메인: pdwo610.shop)  
✅ **High Availability**: Multi-AZ, Auto Scaling, Health Checks  
✅ **IaC**: Terraform으로 전체 인프라 관리  
✅ **Remote State**: S3 Backend + DynamoDB Locking

### 기술 스택

- **IaC**: Terraform ~> 5.0
- **Cloud Provider**: AWS (Seoul, Tokyo)
- **Networking**: VPC, Transit Gateway, VPN, CloudFront
- **Compute**: Elastic Beanstalk (Python 3.11, t3.medium)
- **Database**: Aurora MySQL Global Database (db.r6g.large)
- **DNS**: Route 53 (pdwo610.shop)
- **CDN**: CloudFront (HTTPS, Custom Domain)
- **State Management**: S3 + DynamoDB

---

## 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Global Layer (CloudFront + Route 53)              │
│  ┌──────────────────┐         ┌─────────────────────────────────────────┐  │
│  │  CloudFront CDN  │◄────────┤  Route 53 (pdwo610.shop)                │  │
│  │  *.cloudfront.net│         │  - Hosted Zone: Z05494772SIP68YCM2RD2   │  │
│  └────────┬─────────┘         │  - ACM Certificate (PENDING_VALIDATION)  │  │
│           │ Origins           └─────────────────────────────────────────┘  │
└───────────┼─────────────────────────────────────────────────────────────────┘
            │
    ┌───────┴──────┐
    │              │
┌───▼────────┐  ┌──▼─────────┐
│   Seoul    │  │   Tokyo    │
│  Region    │  │  Region    │
└────────────┘  └────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ Seoul Region (ap-northeast-2)                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ Seoul AWS VPC (20.0.0.0/16)  vpc-08e573a4900e530d3                  │    │
│ │ ┌────────────────┐  ┌────────────────────────────────────────┐      │    │
│ │ │ Public NAT (2) │  │ Private Beanstalk (2)                  │      │    │
│ │ │ - NAT GW       │  │ - seoul-webapp-env                     │      │    │
│ │ │ - ALB          │  │ - EC2 (t3.medium, 2-4 instances)       │      │    │
│ │ └────────────────┘  │ - Aurora Primary (db.r6g.large)        │      │    │
│ │                     └────────────────────────────────────────┘      │    │
│ │                     ┌────────────────┐                              │    │
│ │                     │ TGW Subnet     │                              │    │
│ │                     └───────┬────────┘                              │    │
│ └─────────────────────────────┼───────────────────────────────────────┘    │
│                               │                                             │
│ ┌─────────────────────────────▼───────────────────────────────────────┐    │
│ │ Seoul Transit Gateway (tgw-0645318fdde116ec0)                       │    │
│ │ - Seoul AWS VPC Attachment                                          │    │
│ │ - Seoul IDC VPC (VPN)                                               │    │
│ │ - Tokyo TGW Peering                                                 │    │
│ └─────────────────────────┬───────────────────────────────────────────┘    │
│                           │ VPN                                             │
│ ┌─────────────────────────▼───────────────────────────────────────────┐    │
│ │ Seoul IDC VPC (10.0.0.0/16)  vpc-01c26ae12f8ec9b15                  │    │
│ │ - CGW EC2 (t3.small)                                                │    │
│ │ - DB EC2 (t3.small, MySQL)                                          │    │
│ └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

                              TGW Peering
                                  │
                                  │
┌─────────────────────────────────▼───────────────────────────────────────────┐
│ Tokyo Region (ap-northeast-1)                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ Tokyo AWS VPC (40.0.0.0/16)  vpc-06159dc6f94b291b6                  │    │
│ │ ┌────────────────┐  ┌────────────────────────────────────────┐      │    │
│ │ │ Public NAT (2) │  │ Private Beanstalk (2)                  │      │    │
│ │ │ - NAT GW       │  │ - tokyo-webapp-env                     │      │    │
│ │ │ - ALB          │  │ - EC2 (t3.medium, 2-4 instances)       │      │    │
│ │ └────────────────┘  │ - Aurora Secondary (db.r6g.large)      │      │    │
│ │                     └────────────────────────────────────────┘      │    │
│ │                     ┌────────────────┐                              │    │
│ │                     │ TGW Subnet     │                              │    │
│ │                     └───────┬────────┘                              │    │
│ └─────────────────────────────┼───────────────────────────────────────┘    │
│                               │                                             │
│ ┌─────────────────────────────▼───────────────────────────────────────┐    │
│ │ Tokyo Transit Gateway (tgw-0c202cb272c772a84)                       │    │
│ │ - Tokyo AWS VPC Attachment                                          │    │
│ │ - Seoul TGW Peering                                                 │    │
│ └─────────────────────────┬───────────────────────────────────────────┘    │
│                           │ VPN                                             │
│ ┌─────────────────────────▼───────────────────────────────────────────┐    │
│ │ Tokyo IDC VPC (30.0.0.0/16)  vpc-0c34333a4ac53f6a7                  │    │
│ │ - CGW EC2 (t3.small)                                                │    │
│ │ - DB EC2 (t3.small, MySQL)                                          │    │
│ └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 프로젝트 구조

```
CheonSangYeon/
├── global/                           # 글로벌 공유 리소스
│   ├── s3/                           # Terraform Remote State Backend
│   │   ├── main.tf                   # S3 Bucket + DynamoDB Table
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── vpc/                          # 모든 VPC (Seoul, Tokyo, IDC)
│   │   ├── main.tf                   # 4개 VPC, Subnets, SG
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── README.md
│   │   └── ROUTING_GUIDE.md
│   ├── aurora/                       # Aurora Global Database
│   │   ├── main.tf                   # Seoul (Primary), Tokyo (Secondary)
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── tgw-peering/                  # Transit Gateway Peering
│   │   ├── main.tf                   # Seoul TGW ↔ Tokyo TGW
│   │   └── outputs.tf
│   ├── cloudfront/                   # CloudFront CDN (삭제됨)
│   │   ├── main.tf                   # 재배포 예정 (기본 인증서)
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── route53/                      # Route 53 DNS
│   │   ├── main.tf                   # Hosted Zone, ACM, DNS Records
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── dms/                          # DMS 마이그레이션 (비활성화)
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── Seoul/                            # Seoul 리전 리소스
│   ├── main.tf                       # Beanstalk, TGW, VPN
│   ├── variables.tf
│   ├── outputs.tf
│   ├── README.md
│   └── modules/idc/                  # Seoul IDC 모듈
│       ├── main.tf                   # CGW, DB EC2
│       ├── variables.tf
│       └── outputs.tf
└── Tokyo/                            # Tokyo 리전 리소스
    ├── main.tf                       # Beanstalk, TGW, VPN
    ├── variables.tf
    ├── outputs.tf
    ├── README.md
    └── modules/idc/                  # Tokyo IDC 모듈
        ├── main.tf                   # CGW, DB EC2
        ├── variables.tf
        └── outputs.tf
```

---

## 모듈 상세 설명

### 1. global/s3 - Terraform Remote State Backend

**목적**: Terraform State 파일을 S3에 저장하고 DynamoDB로 잠금 관리

**리소스**:
- S3 Bucket: `terraform-s3-cheonsangyeon`
  - Versioning 활성화
  - AES256 암호화
  - Public Access 차단
- DynamoDB Table: `terraform-Dynamo-CheonSangYeon`
  - LockID (Hash Key)
  - PAY_PER_REQUEST 결제 모드

**배포 위치**: ap-northeast-2 (Seoul)

**사용법**:
```bash
cd global/s3
terraform init
terraform apply
```

---

### 2. global/vpc - VPC 및 네트워크

**목적**: Seoul/Tokyo의 AWS VPC와 IDC VPC 생성

**리소스**:

#### Seoul AWS VPC (20.0.0.0/16)
- VPC ID: `vpc-08e573a4900e530d3`
- Public NAT Subnets (2개): NAT Gateway, ALB
- Private Beanstalk Subnets (2개): EC2 인스턴스
- Transit Gateway Subnet (1개): TGW 연결
- Security Groups: Beanstalk SG, Aurora SG

#### Seoul IDC VPC (10.0.0.0/16)
- VPC ID: `vpc-01c26ae12f8ec9b15`
- Public Subnet: CGW 및 DB 인스턴스
- Internet Gateway

#### Tokyo AWS VPC (40.0.0.0/16)
- VPC ID: `vpc-06159dc6f94b291b6`
- Public NAT Subnets (2개): NAT Gateway, ALB
- Private Beanstalk Subnets (2개): EC2 인스턴스
- Transit Gateway Subnet (1개): TGW 연결
- Security Groups: Beanstalk SG, Aurora SG

#### Tokyo IDC VPC (30.0.0.0/16)
- VPC ID: `vpc-0c34333a4ac53f6a7`
- Public Subnet: CGW 및 DB 인스턴스
- Internet Gateway

**배포 위치**: Seoul + Tokyo (Multi-Region)

**사용법**:
```bash
cd global/vpc
terraform init
terraform apply
```

---

### 3. global/aurora - Aurora Global Database

**목적**: Seoul (Primary)과 Tokyo (Secondary) 간 글로벌 데이터베이스 구성

**리소스**:
- **Global Cluster**: aurora-global-cluster
- **Seoul Primary Cluster**: aurora-global-seoul
  - Writer Endpoint: `aurora-global-seoul.cluster-<id>.ap-northeast-2.rds.amazonaws.com`
  - Instance: db.r6g.large
  - Engine: Aurora MySQL 8.0.mysql_aurora.3.05.2
- **Tokyo Secondary Cluster**: aurora-global-tokyo
  - Reader Endpoint: `aurora-global-tokyo.cluster-ro-<id>.ap-northeast-1.rds.amazonaws.com`
  - Instance: db.r6g.large

**특징**:
- RPO < 1초 (Recovery Point Objective)
- RTO < 1분 (Recovery Time Objective)
- 자동 복제 (Seoul → Tokyo)

**배포 위치**: Seoul (Primary) + Tokyo (Secondary)

**사용법**:
```bash
cd global/aurora
terraform init
terraform apply
```

---

### 4. Seoul - Seoul 리전 인프라

**목적**: Seoul 리전의 Beanstalk, Transit Gateway, VPN 구성

**리소스**:

#### Transit Gateway
- TGW ID: `tgw-0645318fdde116ec0`
- Attachments:
  - Seoul AWS VPC
  - Seoul IDC VPC (VPN)
  - Tokyo TGW (Peering)

#### VPN Connection
- VPN ID: `vpn-<id>`
- Seoul TGW ↔ Seoul IDC CGW
- IPsec Tunnels (2개)

#### Elastic Beanstalk
- Application: seoul-webapp
- Environment: seoul-webapp-env
- Platform: Python 3.11
- Instance Type: t3.medium
- Auto Scaling: 2-4 instances
- CNAME: `seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com`

#### IDC Module (modules/idc)
- CGW EC2: t3.small (Customer Gateway)
- DB EC2: t3.small (MySQL)

**배포 위치**: ap-northeast-2 (Seoul)

**사용법**:
```bash
cd Seoul
terraform init
terraform apply
```

---

### 5. Tokyo - Tokyo 리전 인프라

**목적**: Tokyo 리전의 Beanstalk, Transit Gateway, VPN 구성

**리소스**:

#### Transit Gateway
- TGW ID: `tgw-0c202cb272c772a84`
- Attachments:
  - Tokyo AWS VPC
  - Seoul TGW (Peering)

#### VPN Connection
- VPN ID: `vpn-<id>`
- Tokyo TGW ↔ Tokyo IDC CGW
- IPsec Tunnels (2개)

#### Elastic Beanstalk
- Application: tokyo-webapp
- Environment: tokyo-webapp-env
- Platform: Python 3.11
- Instance Type: t3.medium
- Auto Scaling: 2-4 instances
- CNAME: `tokyo-webapp-env.eba-<id>.ap-northeast-1.elasticbeanstalk.com`

#### IDC Module (modules/idc)
- CGW EC2: t3.small (Customer Gateway)
- DB EC2: t3.small (MySQL)

**배포 위치**: ap-northeast-1 (Tokyo)

**사용법**:
```bash
cd Tokyo
terraform init
terraform apply
```

---

### 6. global/tgw-peering - Transit Gateway Peering

**목적**: Seoul TGW와 Tokyo TGW 간 리전 간 연결

**리소스**:
- Peering Attachment: Seoul → Tokyo
- Peering Accepter: Tokyo
- TGW Routes:
  - Seoul → Tokyo AWS VPC (40.0.0.0/16)
  - Seoul → Tokyo IDC VPC (30.0.0.0/16)
  - Tokyo → Seoul AWS VPC (20.0.0.0/16)
  - Tokyo → Seoul IDC VPC (10.0.0.0/16)

**배포 위치**: Seoul + Tokyo (Multi-Region)

**사용법**:
```bash
cd global/tgw-peering
terraform init
terraform apply
```

---

### 7. global/route53 - Route 53 DNS

**목적**: 도메인 관리 및 ACM 인증서 발급

**리소스**:
- **Hosted Zone**: pdwo610.shop
  - Zone ID: `Z05494772SIP68YCM2RD2`
  - Name Servers:
    - ns-1375.awsdns-43.org
    - ns-1691.awsdns-19.co.uk
    - ns-54.awsdns-06.com
    - ns-817.awsdns-38.net

- **ACM Certificate**: pdwo610.shop, *.pdwo610.shop
  - ARN: `arn:aws:acm:us-east-1:299145660695:certificate/e8efcfba-b8d7-4da0-a3be-c4b82e5b17b4`
  - Status: `PENDING_VALIDATION` (NS 레코드 설정 필요)

- **DNS Records**:
  - A/AAAA (root): Seoul/Tokyo Beanstalk (Weighted Routing)
  - A/AAAA (www): Seoul/Tokyo Beanstalk (Weighted Routing)
  - CNAME (seoul): Seoul Beanstalk
  - CNAME (tokyo): Tokyo Beanstalk

- **Health Checks**:
  - Seoul Beanstalk Health Check
  - Tokyo Beanstalk Health Check

**배포 위치**: ap-northeast-2 (Seoul), us-east-1 (ACM)

**현재 상태**: ✅ 배포 완료 (15 리소스)

**사용법**:
```bash
cd global/route53
terraform init
terraform apply
```

---

### 8. global/cloudfront - CloudFront CDN

**목적**: 글로벌 CDN을 통한 콘텐츠 배포

**리소스** (현재 삭제됨):
- CloudFront Distribution
- Cache Policy (optimized)
- Origin Request Policy (all_viewer)
- Response Headers Policy (security_headers)
- CloudFront Function (url_rewrite)
- Origin Access Control

**현재 상태**: 🔴 삭제됨 (재배포 예정)

**재배포 전략**:
1. 기본 인증서로 CloudFront 배포
2. Route 53 NS 레코드 설정 대기
3. ACM 인증서 검증 완료
4. CloudFront에 커스텀 도메인 적용 (Terraform 또는 콘솔)

**사용법**:
```bash
cd global/cloudfront
terraform init
terraform apply
```

---

### 9. global/dms - DMS 마이그레이션

**목적**: IDC DB → Aurora로 데이터 마이그레이션

**현재 상태**: 🔴 비활성화 (Terraform state에서 제거됨)

**리소스** (비활성화):
- DMS Replication Instance
- Source Endpoint (IDC DB)
- Target Endpoint (Aurora)
- Replication Task

**사용법** (옵션):
```bash
cd global/dms
terraform init
terraform apply
```

---

## 배포 가이드

### 배포 순서

> ⚠️ **중요**: 반드시 아래 순서대로 배포해야 합니다. 모듈 간 의존성이 있습니다.

#### 1. S3 Backend 생성
```bash
cd global/s3
terraform init
terraform apply
```

출력:
- S3 Bucket: `terraform-s3-cheonsangyeon`
- DynamoDB Table: `terraform-Dynamo-CheonSangYeon`

#### 2. VPC 생성
```bash
cd global/vpc
terraform init
terraform apply
```

출력:
- Seoul VPC: `vpc-08e573a4900e530d3`
- Seoul IDC VPC: `vpc-01c26ae12f8ec9b15`
- Tokyo VPC: `vpc-06159dc6f94b291b6`
- Tokyo IDC VPC: `vpc-0c34333a4ac53f6a7`

#### 3. Aurora Global Database 생성
```bash
cd global/aurora
terraform init
terraform apply
```

출력:
- Seoul Cluster: `aurora-global-seoul`
- Tokyo Cluster: `aurora-global-tokyo`

#### 4. Seoul 리전 배포
```bash
cd Seoul
terraform init
terraform apply
```

출력:
- Transit Gateway: `tgw-0645318fdde116ec0`
- Beanstalk CNAME: `seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com`

#### 5. Tokyo 리전 배포 (현재 삭제됨)
```bash
cd Tokyo
terraform init
terraform apply
```

출력:
- Transit Gateway: `tgw-0c202cb272c772a84`
- Beanstalk CNAME: `tokyo-webapp-env.eba-<id>.ap-northeast-1.elasticbeanstalk.com`

**현재 상태**: 🔴 삭제됨 (DR 전략 변경: AWS → Azure)

#### 6. Transit Gateway Peering (현재 삭제됨)
```bash
cd global/tgw-peering
terraform init
terraform apply
```

출력:
- Peering Attachment ID: `tgw-attach-<id>`

**현재 상태**: 🔴 삭제됨 (Tokyo 리전 삭제로 인해 불필요)

#### 7. Route 53 배포
```bash
cd global/route53
terraform init
terraform apply
```

출력:
- Hosted Zone: `Z05494772SIP68YCM2RD2`
- ACM Certificate ARN: `arn:aws:acm:us-east-1:299145660695:certificate/e8efcfba-b8d7-4da0-a3be-c4b82e5b17b4`

#### 8. CloudFront 배포 (예정)

**Option A: Terraform으로 기본 배포**
```bash
cd global/cloudfront
terraform init
terraform apply
```

**Option B: 콘솔에서 수동 설정** (권장)
1. CloudFront Distribution 생성 (기본 인증서)
2. Route 53 NS 레코드 설정 (도메인 등록 기관)
3. ACM 인증서 검증 완료 대기
4. CloudFront에 커스텀 도메인 추가 (콘솔)

---

### Azure DR 환경 배포 순서

> 🔄 **멀티 클라우드 DR**: AWS (Primary) + Azure (DR)

#### 9. Azure 기본 인프라 배포
```bash
cd Azure
terraform init
terraform apply
```

출력:
- Resource Group: `rg-dr-multicloud`
- VNet: `vnet-dr-multicloud` (50.0.0.0/16)
- VPN Gateway: Azure VPN Gateway
- MySQL: `mysql-dr-multicloud` (Private: 50.0.2.4)
- App Service: `webapp-dr-multicloud` (ECR 기반)

**주요 리소스**:
- VNet Subnets:
  - Gateway Subnet: 50.0.0.0/24
  - App Subnet: 50.0.1.0/24
  - DB Subnet: 50.0.2.0/24
- VPN Connection: Azure ↔ AWS VPN
- MySQL Flexible Server: Private VNet Integration
- App Service: Linux (ECR Container)

#### 10. AWS-Azure VPN 연결 설정
```bash
cd AWS_Seoul_Test
terraform init
terraform apply
```

출력:
- VPN Connection: `vpn-0d25ac381ee624408`
- Tunnel 1: 3.39.70.44 (UP)
- Transit Gateway Route: 50.0.0.0/16 (active)

**VPN 상태 확인**:
```bash
# AWS VPN Tunnel 상태
aws ec2 describe-vpn-connections --vpn-connection-ids vpn-0d25ac381ee624408 --region ap-northeast-2

# Azure VPN 연결 상태
az network vpn-connection show \
  --name azure-to-aws-vpn \
  --resource-group rg-dr-multicloud \
  --query connectionStatus
```

#### 11. DMS 마이그레이션 설정 (Aurora → Azure MySQL)
```bash
cd global/dms
terraform init
terraform apply
```

출력:
- Replication Instance: `aurora-migration-replication-instance`
- Source Endpoint: `source-aurora-mysql` (Aurora)
- Target Endpoint: `target-azure-mysql` (50.0.2.4)
- Migration Task: `aurora-to-azure-migration-task`

**마이그레이션 시작**:
```bash
aws dms start-replication-task \
  --replication-task-arn arn:aws:dms:ap-northeast-2:299145660695:task:4XGU77BA5ZDKZCJWAMCT2KES2A \
  --start-replication-task-type start-replication
```

**마이그레이션 상태 확인**:
```bash
aws dms describe-replication-tasks \
  --filters Name=replication-task-arn,Values=arn:aws:dms:ap-northeast-2:299145660695:task:4XGU77BA5ZDKZCJWAMCT2KES2A
```

#### 12. Azure App Service ECR 배포

**사전 준비**:
1. ECR 인증 토큰 생성:
   ```bash
   aws ecr get-login-password --region ap-northeast-2
   ```

2. `Azure/terraform.tfvars` 업데이트:
   ```terraform
   ecr_registry_url = "299145660695.dkr.ecr.ap-northeast-2.amazonaws.com"
   ecr_image_name   = "seoul-portal-seoul-frontend:latest"
   ecr_password     = "<ECR_TOKEN>"  # 12시간 유효
   ```

**배포**:
```bash
cd Azure
terraform apply -auto-approve
```

출력:
- App Service URL: `https://webapp-dr-multicloud.azurewebsites.net`
- Container Image: ECR Frontend
- Database: Azure MySQL (50.0.2.4)

**배포 검증**:
```bash
# Health Check
curl https://webapp-dr-multicloud.azurewebsites.net/health

# 로그 확인
az webapp log tail \
  --name webapp-dr-multicloud \
  --resource-group rg-dr-multicloud
```

---

## 현재 인프라 상태

### 배포 완료 ✅

| 모듈 | 상태 | 주요 리소스 |
|------|------|-------------|
| **global/s3** | ✅ 배포 완료 | S3 Bucket, DynamoDB Table |
| **global/vpc** | ✅ 배포 완료 | 4개 VPC, Subnets, SG |
| **global/aurora** | ✅ 배포 완료 | Aurora Global Cluster (Seoul Primary) |
| **Seoul** | ✅ 배포 완료 | TGW, VPN, Beanstalk, IDC |
| **Tokyo** | 🔴 삭제됨 | DR 전략 변경: AWS → Azure |
| **global/tgw-peering** | 🔴 삭제됨 | Tokyo 리전 삭제로 불필요 |
| **global/route53** | ✅ 배포 완료 | Hosted Zone, ACM, DNS Records |
| **Azure** | ✅ 배포 완료 | VNet, VPN, MySQL, App Service |
| **AWS-Azure VPN** | ✅ 연결 성공 | Tunnel UP, Route active |
| **global/dms** | ✅ 마이그레이션 완료 | Aurora → Azure MySQL (100%) |

### 배포 대기 ⏳

| 모듈 | 상태 | 다음 단계 |
|------|------|-----------|
| **global/cloudfront** | 🔴 삭제됨 | 재배포 예정 (기본 인증서) |
| **ACM Certificate** | ⏳ PENDING_VALIDATION | 도메인 NS 레코드 설정 필요 |
| **Azure App Service ECR** | ⏳ 배포 대기 | ECR 자격 증명 설정 후 apply |

---

### 주요 리소스 ID

#### Seoul Region (ap-northeast-2)
| 리소스 | ID/ARN/Endpoint |
|--------|-----------------|
| Seoul VPC | `vpc-08e573a4900e530d3` |
| Seoul IDC VPC | `vpc-01c26ae12f8ec9b15` |
| Seoul TGW | `tgw-0645318fdde116ec0` |
| Seoul Beanstalk | `seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com` |
| Aurora Primary | `aurora-global-seoul.cluster-<id>.ap-northeast-2.rds.amazonaws.com` |
| VPN to Azure | `vpn-0d25ac381ee624408` (Tunnel 1: UP) |

#### Tokyo Region (ap-northeast-1)
| 리소스 | ID/ARN/Endpoint |
|--------|-----------------|
| Tokyo VPC | 🔴 삭제됨 |
| Tokyo IDC VPC | 🔴 삭제됨 |
| Tokyo TGW | 🔴 삭제됨 |
| Tokyo Beanstalk | 🔴 삭제됨 |
| Aurora Secondary | 🔴 삭제됨 |

#### Azure Korea Central
| 리소스 | ID/ARN/Endpoint |
|--------|-----------------|
| Resource Group | `rg-dr-multicloud` |
| VNet | `vnet-dr-multicloud` (50.0.0.0/16) |
| VPN Gateway | `vpngateway-dr-multicloud` (20.194.99.75) |
| Local Network Gateway | `aws-seoul-lgw` (3.39.70.44) |
| VPN Connection | `azure-to-aws-vpn` (Connected) |
| MySQL Server | `mysql-dr-multicloud` (Private: 50.0.2.4) |
| MySQL Database | `webapp_db` |
| App Service | `webapp-dr-multicloud.azurewebsites.net` |
| App Service Plan | `plan-dr-multicloud` (P1v3) |

#### Global Resources
| 리소스 | ID/ARN/Endpoint |
|--------|-----------------|
| S3 Backend | `terraform-s3-cheonsangyeon` |
| DynamoDB Lock | `terraform-Dynamo-CheonSangYeon` |
| Route 53 Zone | `Z05494772SIP68YCM2RD2` |
| ACM Certificate | `arn:aws:acm:us-east-1:299145660695:certificate/e8efcfba-b8d7-4da0-a3be-c4b82e5b17b4` |
| Domain | `pdwo610.shop` |
| DMS Replication Instance | `aurora-migration-replication-instance` |
| DMS Migration Task | `aurora-to-azure-migration-task` (완료) |
| ECR Repository | `seoul-portal-seoul-frontend` |

---

## 비용 예상

| 리소스 | 수량 | 월 예상 비용 (USD) |
|--------|------|--------------------|
| **Seoul NAT Gateway** | 2 | $65.70 |
| **Tokyo NAT Gateway** | 2 | $72.54 |
| **Seoul Beanstalk EC2 (t3.medium)** | 2-4 | $58.40 - $116.80 |
| **Tokyo Beanstalk EC2 (t3.medium)** | 2-4 | $64.58 - $129.16 |
| **Seoul Transit Gateway** | 1 | $36.50 |
| **Tokyo Transit Gateway** | 1 | $36.50 |
| **TGW Peering** | 1 | $36.50 |
| **Seoul Aurora (db.r6g.large)** | 1 | $167.52 |
| **Tokyo Aurora (db.r6g.large)** | 1 | $185.04 |
| **Seoul ALB** | 1 | $16.20 |
| **Tokyo ALB** | 1 | $17.84 |
| **Seoul VPN** | 1 | $36.00 |
| **Tokyo VPN** | 1 | $36.00 |
| **Seoul CGW EC2 (t3.small)** | 1 | $29.20 |
| **Tokyo CGW EC2 (t3.small)** | 1 | $32.29 |
| **Seoul IDC DB EC2 (t3.small)** | 1 | $29.20 |
| **Tokyo IDC DB EC2 (t3.small)** | 1 | $32.29 |
| **CloudFront** | 1 | $50.00 - $100.00 |
| **Route 53 Hosted Zone** | 1 | $0.50 |
| **데이터 전송** | - | $30.00 - $50.00 |
| **총 예상 비용** | | **~$1,000 - $1,200/월** |

> ⚠️ 실제 비용은 트래픽, Auto Scaling, 데이터 전송량에 따라 달라질 수 있습니다.

---

## 트러블슈팅

### 1. ACM 인증서 검증 타임아웃

**문제**: ACM 인증서가 10분 후 타임아웃되며 `PENDING_VALIDATION` 상태 유지

**원인**: 
- Route 53 Name Servers가 도메인 등록 기관에 설정되지 않음
- 도메인명 불일치 (예: cloudupcon.com ≠ pdwo610.shop)

**해결**:
1. Route 53 Name Servers 확인:
   ```bash
   cd global/route53
   terraform output name_servers
   ```
   출력:
   ```
   ns-1375.awsdns-43.org
   ns-1691.awsdns-19.co.uk
   ns-54.awsdns-06.com
   ns-817.awsdns-38.net
   ```

2. 도메인 등록 기관(pdwo610.shop 구매처)에 NS 레코드 설정
3. DNS 전파 대기 (5~30분)
4. ACM 상태 확인:
   ```bash
   aws acm describe-certificate \
     --certificate-arn arn:aws:acm:us-east-1:299145660695:certificate/e8efcfba-b8d7-4da0-a3be-c4b82e5b17b4 \
     --region us-east-1
   ```

---

### 2. CloudFront 403 ERROR

**문제**: pdwo610.shop 접속 시 403 ERROR 발생

**원인**:
- CloudFront에 커스텀 도메인 미설정
- ACM 인증서가 `PENDING_VALIDATION` 상태
- Route 53 Name Servers 미설정

**해결**:
1. Route 53 NS 레코드 설정 (위 참조)
2. ACM 인증서 검증 완료 대기
3. CloudFront 재배포:
   ```bash
   cd global/cloudfront
   terraform apply
   ```
4. 또는 콘솔에서 수동 설정:
   - CloudFront Distribution → Edit
   - Alternate domain names: `pdwo610.shop`, `www.pdwo610.shop`
   - Custom SSL certificate: ACM 인증서 선택
   - Save changes

---

### 3. CloudFront 삭제 시 Route 53 의존성 에러

**문제**: Route 53 삭제 중 CloudFront가 `data.terraform_remote_state.route53.outputs` 참조 시도

**에러**:
```
Error: Unsupported attribute
│ 
│   on main.tf line 55, in resource "aws_cloudfront_distribution" "main":
│   55:   aliases = [var.domain_name, "www.${var.domain_name}"]
│ 
│ This object does not have an attribute named "route53".
```

**원인**: CloudFront가 Route 53 state를 참조하는데, Route 53이 먼저 삭제됨

**해결**:
1. CloudFront 코드를 기본 설정으로 복구:
   ```terraform
   # data "terraform_remote_state" "route53" 제거
   # aliases 제거
   viewer_certificate {
     cloudfront_default_certificate = true
   }
   ```

2. CloudFront 먼저 삭제:
   ```bash
   cd global/cloudfront
   terraform destroy
   ```

3. Route 53 삭제:
   ```bash
   cd global/route53
   terraform destroy
   ```

---

### 4. VPN 연결 실패

**문제**: Seoul/Tokyo TGW와 IDC CGW 간 VPN 연결 실패

**원인**: Customer Gateway IP가 잘못 설정됨

**해결**:
1. CGW Instance의 Elastic IP 확인:
   ```bash
   cd Seoul  # 또는 Tokyo
   terraform output idc_cgw_instance_public_ip
   ```

2. Customer Gateway 수정:
   ```terraform
   resource "aws_customer_gateway" "idc" {
     ip_address = module.idc.cgw_instance_public_ip  # 올바른 IP 확인
     ...
   }
   ```

3. 재배포:
   ```bash
   terraform apply
   ```

---

### 5. Aurora 복제 지연

**문제**: Tokyo Secondary Cluster에서 데이터 지연 발생

**원인**: 리전 간 네트워크 레이턴시

**해결**:
- Aurora Global Database는 일반적으로 RPO < 1초 제공
- 복제 지연 모니터링:
  ```sql
  SHOW SLAVE STATUS\G
  ```
- 지연이 계속되면 AWS 지원팀 문의

---

### 6. Beanstalk 배포 실패

**문제**: Elastic Beanstalk Environment가 생성되지 않음

**원인**: Subnet 구성 오류 (ELB는 퍼블릭, EC2는 프라이빗)

**해결**:
1. Subnet 설정 확인:
   ```terraform
   resource "aws_elastic_beanstalk_environment" "seoul_env" {
     ...
     setting {
       namespace = "aws:ec2:vpc"
       name      = "ELBSubnets"
       value     = join(",", data.terraform_remote_state.global_vpc.outputs.seoul_public_nat_subnet_ids)  # 퍼블릭
     }
     setting {
       namespace = "aws:ec2:vpc"
       name      = "Subnets"
       value     = join(",", data.terraform_remote_state.global_vpc.outputs.seoul_private_beanstalk_subnet_ids)  # 프라이빗
     }
   }
   ```

2. 재배포:
   ```bash
   terraform apply
   ```

---

### 7. Terraform State Drift (콘솔 수정 후)

**문제**: 콘솔에서 CloudFront 수동 설정 후 `terraform apply` 시 기본 설정으로 되돌아감

**원인**: Terraform은 코드 상태를 실제 인프라에 강제 적용

**해결**:

**Option A: IaC 유지 (권장)**
1. Terraform 코드에 커스텀 도메인 반영:
   ```terraform
   resource "aws_cloudfront_distribution" "main" {
     aliases = ["pdwo610.shop", "www.pdwo610.shop"]
     
     viewer_certificate {
       acm_certificate_arn      = data.terraform_remote_state.route53.outputs.acm_certificate_arn
       ssl_support_method       = "sni-only"
       minimum_protocol_version = "TLSv1.2_2021"
     }
   }
   ```

2. 재배포:
   ```bash
   terraform apply
   ```

**Option B: 콘솔 우선**
1. Terraform 코드를 현재 콘솔 상태에 맞춤
2. `terraform import`로 기존 리소스 가져오기
3. State Drift 해결

---

## 다음 단계

### 1. 도메인 NS 레코드 설정 ⏳

**작업**: pdwo610.shop 도메인 등록 기관에서 NS 레코드 설정

**NS 레코드**:
```
ns-1375.awsdns-43.org
ns-1691.awsdns-19.co.uk
ns-54.awsdns-06.com
ns-817.awsdns-38.net
```

**예상 소요 시간**: 5~30분 (DNS 전파)

---

### 2. ACM 인증서 검증 완료 대기 ⏳

**작업**: NS 레코드 설정 후 자동 검증

**상태 확인**:
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:299145660695:certificate/e8efcfba-b8d7-4da0-a3be-c4b82e5b17b4 \
  --region us-east-1 \
  --query 'Certificate.Status'
```

**예상 상태 변화**: `PENDING_VALIDATION` → `ISSUED`

---

### 3. CloudFront 재배포 ⏳

**Option A: Terraform (IaC 유지)**
```bash
cd global/cloudfront
# main.tf 수정 (Route 53 참조, aliases, ACM 인증서)
terraform apply
```

**Option B: 콘솔 (빠른 설정)**
1. CloudFront Distribution 생성 (기본 인증서)
2. ACM 검증 완료 후
3. CloudFront → Edit
   - Alternate domain names: `pdwo610.shop`, `www.pdwo610.shop`
   - Custom SSL certificate: ACM 인증서 선택
4. Save changes (배포 15~20분)

---

### 4. HTTPS 접속 테스트 ✅

**테스트 URL**:
- https://pdwo610.shop
- https://www.pdwo610.shop
- https://seoul.pdwo610.shop
- https://tokyo.pdwo610.shop

**예상 결과**: Beanstalk 애플리케이션 정상 로드

---

### 5. 모니터링 및 최적화 📊

**CloudWatch 설정**:
- CloudFront 메트릭 모니터링
- Beanstalk Health Checks
- Aurora Performance Insights
- VPN Tunnel Status

**비용 최적화**:
- Reserved Instances (Beanstalk EC2)
- Aurora Serverless v2 검토
- NAT Gateway → NAT Instance (비용 절감)

---

## 추가 참고 자료

- [AWS Transit Gateway 문서](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [Aurora Global Database 문서](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- [Elastic Beanstalk 문서](https://docs.aws.amazon.com/elasticbeanstalk/)
- [CloudFront 문서](https://docs.aws.amazon.com/cloudfront/)
- [Route 53 문서](https://docs.aws.amazon.com/route53/)
- [ACM 인증서 검증 가이드](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)

---

## 보안 고려사항

⚠️ **중요**: 
- Terraform State 파일에 민감 정보 포함 (DB 비밀번호, 키 등)
- `terraform.tfstate` 파일을 Git에 커밋하지 마세요
- S3 Backend 사용 시 `.gitignore`에 `*.tfstate` 추가
- Aurora Master Password는 Secrets Manager 사용 권장
- IAM 최소 권한 원칙 적용

---

## 라이선스

이 프로젝트는 학습 목적으로 작성되었습니다.

---

**마지막 업데이트**: 2025년  
**작성자**: CheonSangYeon  
**Terraform 버전**: ~> 5.0  
**AWS Provider 버전**: ~> 5.0
