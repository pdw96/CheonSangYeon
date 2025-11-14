# Terraform AWS Infrastructure (모듈화)

## 프로젝트 구조

```
.
├── main.tf                      # 메인 설정 및 모듈 호출
├── variables.tf                 # 루트 변수
├── outputs.tf                   # 루트 출력
├── terraform.tfvars.example     # 변수 예제 파일
├── modules/
│   ├── tokyo/                   # Tokyo 리전 모듈
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── idc/                     # IDC 리전 모듈
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

## 구성 요소

### Tokyo 모듈 (ap-northeast-1)
- **VPC**: 10.0.0.0/16
- **NAT Gateway용 퍼블릭 서브넷** 2개 (AZ-a, AZ-c)
- **Elastic Beanstalk용 프라이빗 서브넷** 2개 (AZ-a, AZ-c)
- **CGW 인스턴스용 퍼블릭 서브넷** 1개
- **Transit Gateway용 서브넷** 1개
- **NAT Gateway** 2개
- **CGW EC2 인스턴스** 1개

### IDC 모듈 (도쿄 리전 내 배치)
- **VPC**: 172.16.0.0/16
- **CGW용 퍼블릭 서브넷** 1개 + CGW 인스턴스
- **Transit Gateway용 서브넷** 1개

## 네트워크 통신

- **도쿄 VPC ↔ IDC VPC**: 두 가지 연결 방식
  1. **Transit Gateway**: 같은 리전 내 직접 연결
  2. **Site-to-Site VPN**: CGW를 통한 IPsec VPN 터널 (수동 설정)
     - IDC CGW 인스턴스를 Customer Gateway로 등록
     - VPN Connection은 EC2 인스턴스에 직접 접속하여 수동 설정
- **인터넷 통신**: 
  - 도쿄 VPC: NAT Gateway 사용 (Beanstalk 서브넷)
  - IDC VPC: Internet Gateway 사용 (CGW 서브넷)

## Site-to-Site VPN 설정 (EC2 간 직접 IPsec 터널)

Tokyo CGW와 IDC CGW 인스턴스 간 IPsec 터널이 **완전 자동으로 구성**됩니다:

### 자동 설정 내용
- 양쪽 CGW 인스턴스에 StrongSwan 자동 설치
- Pre-shared Key 자동 생성 및 배포
- IPsec 터널 설정 자동 구성
- Source/Destination Check 자동 비활성화
- 터널 자동 시작 및 연결

### 사용 방법

1. **terraform.tfvars 파일 설정**:
```bash
tokyo_key_name       = "your-key-name"
ssh_private_key_path = "~/.ssh/your-key.pem"
```

2. **Terraform 실행**:
```bash
terraform init
terraform apply
```

3. **VPN 상태 확인**:
```bash
# 엔드포인트 정보 확인
terraform output vpn_endpoints

# Tokyo CGW에서 확인
ssh -i your-key.pem ec2-user@<TOKYO_CGW_IP>
sudo strongswan status

# IDC CGW에서 확인
ssh -i your-key.pem ec2-user@<IDC_CGW_IP>
sudo strongswan status
```

### 주요 특징
- **AWS Managed VPN 불필요**: EC2 인스턴스 간 직접 IPsec 연결
- **비용 절감**: VPN Gateway 비용 없음
- **완전 자동화**: 수동 설정 불필요
- **양방향 통신**: 10.0.0.0/16 ↔ 172.16.0.0/16

### 주의사항
- SSH private key 경로를 정확히 설정해야 합니다
- Security Group에서 UDP 500, 4500 포트가 열려있어야 합니다
- ESP 프로토콜(IP Protocol 50)이 허용되어야 합니다

## 모듈화 장점

- **재사용성**: 각 모듈을 독립적으로 재사용 가능
- **유지보수성**: 리전별로 코드가 분리되어 관리 용이
- **확장성**: 새로운 리전 추가 시 모듈만 호출하면 됨
- **테스트 용이**: 각 모듈을 독립적으로 테스트 가능

## 사용 방법

1. `terraform.tfvars.example`을 `terraform.tfvars`로 복사하고 키 페어 정보 입력:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Terraform 초기화:
```bash
terraform init
```

3. 실행 계획 확인:
```bash
terraform plan
```

4. 인프라 배포:
```bash
terraform apply
```

## 주의사항

- EC2 인스턴스 실행을 위해 각 리전에 키 페어가 미리 생성되어 있어야 합니다
- IDC 환경에서는 Elastic IP를 사용하지 않습니다
- AMI ID는 2024년 기준이며, 최신 버전 확인 필요할 수 있습니다
- 모듈을 수정할 때는 `terraform init -upgrade` 실행 필요

