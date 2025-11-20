# Seoul Region Infrastructure

Seoul 리전의 AWS 인프라를 관리합니다.

## 프로젝트 구조

```
Seoul/
├── main.tf                      # 메인 설정 및 리소스
├── variables.tf                 # 변수 정의
├── outputs.tf                   # 출력 값
└── terraform.tfvars.example     # 변수 예제
```

## 구성 요소

### Seoul AWS VPC (20.0.0.0/16)
- **VPC ID**: vpc-0ed96f16d7a1c201b
- **Public NAT Subnets**: 2개 (AZ-a, AZ-c)
  - NAT Gateways
  - ELB(Load Balancer)
- **Private Beanstalk Subnets**: 2개 (AZ-a, AZ-c)
  - EC2 인스턴스
- **Transit Gateway Subnet**: Seoul-Tokyo 연결

### Seoul IDC VPC (10.0.0.0/16)
- **VPC ID**: vpc-0d31886e9f4dc578c
- **Public Subnets**: CGW 및 DB 인스턴스
- **VPN Connection**: vpn-089edd593ccea148e (Seoul TGW ↔ Seoul IDC CGW)

### Transit Gateway
- **ID**: tgw-00aa475a8ec145dc4
- **연결**:
  - Seoul AWS VPC
  - Seoul IDC VPC (VPN)
  - Tokyo TGW (Peering)

### Elastic Beanstalk
- **Environment**: seoul-webapp-env
- **Platform**: Python 3.11
- **Instance Type**: t3.medium
- **Load Balancer**: Application Load Balancer (internet-facing)
  - **ELB Subnets**: 퍼블릭 NAT 서브넷 (인터넷 접속용)
  - **EC2 Subnets**: 프라이빗 Beanstalk 서브넷 (보안)
- **Auto Scaling**: 2-4 인스턴스
- **CNAME**: seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com

## 네트워크 통신

### Seoul AWS ↔ Seoul IDC
- **VPN Connection**: Site-to-Site VPN (IPsec)
- **Transit Gateway**: Seoul TGW를 통한 라우팅
- **통신 경로**: Seoul Beanstalk → Seoul TGW → VPN → Seoul IDC DB

### Seoul ↔ Tokyo
- **Transit Gateway Peering**: Seoul TGW ↔ Tokyo TGW
- **통신 경로**: 
  - Seoul AWS (20.0.0.0/16) ↔ Tokyo AWS (40.0.0.0/16)
  - Seoul IDC (10.0.0.0/16) ↔ Tokyo IDC (30.0.0.0/16)

### 인터넷 통신
- **퍼블릭 접속**: Internet Gateway → ELB (퍼블릭 서브넷)
- **아웃바운드**: EC2 (프라이빗 서브넷) → NAT Gateway → Internet Gateway

## 사용 방법

### 1. terraform.tfvars 파일 설정
```bash
cp terraform.tfvars.example terraform.tfvars
# seoul_key_name 및 ssh_private_key_path 설정
```

### 2. Terraform 실행
```bash
cd Seoul
terraform init
terraform plan
terraform apply
```

### 3. Beanstalk 웹 접속 확인
```bash
# HTTP 접속
curl http://seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com

# 브라우저에서
# http://seoul-webapp-env.eba-ztq5m3vp.ap-northeast-2.elasticbeanstalk.com
```

### 4. VPN 상태 확인
```bash
# VPN 연결 상태
aws ec2 describe-vpn-connections \
  --vpn-connection-ids vpn-089edd593ccea148e \
  --region ap-northeast-2

# IDC CGW에서 확인
ssh -i your-key.pem ec2-user@<IDC_CGW_IP>
sudo strongswan status
```

## Beanstalk 주요 설정

### VPC 설정
- **VPC**: Seoul AWS VPC (vpc-0ed96f16d7a1c201b)
- **ELBSubnets**: 퍼블릭 NAT 서브넷 (로드밸런서 배치)
  - subnet-0e03e15d079667bfa
  - subnet-0d7cc41f34a9b6aed
- **Subnets**: 프라이빗 Beanstalk 서브넷 (EC2 인스턴스 배치)
  - subnet-07ef92ca57b27667b
  - subnet-0decc928be8ee6c4a
- **ELBScheme**: public (인터넷 접속 가능)
- **AssociatePublicIpAddress**: false (프라이빗 서브넷)

### 보안
- **Security Group**: HTTP(80), HTTPS(443) from 0.0.0.0/0
- **Health Check**: TCP:80
- **SSL/TLS**: ACM 인증서 적용 가능 (HTTPS 설정 시)

## 주의사항

- EC2 키 페어가 Seoul 리전에 미리 생성되어 있어야 합니다
- Global VPC 모듈이 먼저 배포되어야 합니다
- Transit Gateway 및 VPN 설정은 자동으로 구성됩니다
- Beanstalk 환경 업데이트 시 약 3-5분 소요됩니다

## 트러블슈팅

### Beanstalk 웹 접속 불가
1. ELB 상태 확인:
   ```bash
   aws elbv2 describe-load-balancers --region ap-northeast-2
   ```

2. Target Health 확인:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <TG_ARN> \
     --region ap-northeast-2
   ```

3. Security Group 확인:
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <SG_ID> \
     --region ap-northeast-2
   ```

### VPN 연결 끊김
1. VPN 상태 확인 후 재시작:
   ```bash
   ssh -i your-key.pem ec2-user@<IDC_CGW_IP>
   sudo strongswan restart
   ```

