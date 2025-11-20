# Global VPC Module

This module manages all VPC resources for Seoul and Tokyo regions, including their respective IDC VPCs.

## Structure

### Seoul AWS VPC (20.0.0.0/16)
- **VPC ID**: vpc-0ed96f16d7a1c201b
- **Public NAT Subnets**: 2개 (AZ-a, AZ-c)
  - NAT Gateways 배치용
  - ELB(Load Balancer) 배치용
- **Private Beanstalk Subnets**: 2개 (AZ-a, AZ-c)
  - EC2 인스턴스 배치용
- **Transit Gateway Subnet**: 1개
  - Seoul-Tokyo 리전 간 연결

### Seoul IDC VPC (10.0.0.0/16)
- **VPC ID**: vpc-0d31886e9f4dc578c
- **Public Subnets**: 
  - CGW 인스턴스용
  - DB 인스턴스용
- **VPN Connection**: Seoul TGW와 연결 (vpn-089edd593ccea148e)

### Tokyo AWS VPC (40.0.0.0/16)
- **VPC ID**: vpc-04aaeab19ae7b6fb0
- **Public NAT Subnets**: 2개 (AZ-a, AZ-c)
  - NAT Gateways 배치용
- **Private Beanstalk Subnets**: 2개 (AZ-a, AZ-c)
  - EC2 인스턴스 배치용
- **Transit Gateway Subnet**: 1개
  - Seoul-Tokyo 리전 간 연결

### Tokyo IDC VPC (30.0.0.0/16)
- **VPC ID**: vpc-0ab7dcbb86c69455d
- **Public Subnets**:
  - CGW 인스턴스용
  - DB 인스턴스용

## Security Groups

### Seoul
- **Beanstalk SG**: HTTP(80), HTTPS(443) from 0.0.0.0/0
- **RDS SG**: MySQL(3306) from Beanstalk SG
- **VPN SG**: IPsec (UDP 500, 4500, ESP)

### Tokyo
- **Beanstalk SG**: HTTP(80), HTTPS(443) from 0.0.0.0/0
- **RDS SG**: MySQL(3306) from Beanstalk SG

## Usage

```bash
cd global/vpc
terraform init -backend-config="bucket=YOUR_BUCKET_NAME"
terraform apply
```

## Transit Gateway

Seoul 리전에만 Transit Gateway가 생성됩니다:
- Seoul TGW는 Seoul AWS VPC, Seoul IDC VPC를 연결
- Tokyo TGW와는 Peering 연결

## Outputs

모든 VPC ID, 서브넷 ID, 라우팅 테이블 ID, 보안 그룹 ID가 출력되어 다른 모듈에서 사용됩니다:
- `seoul_vpc_id`, `seoul_public_nat_subnet_ids`, `seoul_private_beanstalk_subnet_ids`
- `seoul_idc_vpc_id`, `seoul_idc_public_subnet_ids`
- `tokyo_vpc_id`, `tokyo_public_nat_subnet_ids`, `tokyo_private_beanstalk_subnet_ids`
- `tokyo_idc_vpc_id`, `tokyo_idc_public_subnet_ids`
