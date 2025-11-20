# Transit Gateway Peering

Seoul과 Tokyo 리전 간 Transit Gateway Peering 구성

## 아키텍처

```
Seoul TGW (tgw-00aa475a8ec145dc4)
    ↕ Peering
Tokyo TGW (tgw-0e65a88096c497691)
```

## 라우팅

**Seoul TGW Routes:**
- `40.0.0.0/16` → Tokyo AWS VPC
- `30.0.0.0/16` → Tokyo IDC VPC

**Tokyo TGW Routes:**
- `20.0.0.0/16` → Seoul AWS VPC
- `10.0.0.0/16` → Seoul IDC VPC

## VPC 연결

**Seoul TGW 연결:**
- Seoul AWS VPC (20.0.0.0/16) - Direct Attachment
- Seoul IDC VPC (10.0.0.0/16) - VPN Connection

**Tokyo TGW 연결:**
- Tokyo AWS VPC (40.0.0.0/16) - Direct Attachment
- Tokyo IDC VPC (30.0.0.0/16) - Direct Attachment (같은 리전)

## 배포

```bash
cd global/tgw-peering
terraform init
terraform plan
terraform apply
```

## 전제 조건

- Seoul Transit Gateway가 배포되어 있어야 함 (Seoul 모듈에서 생성)
- Tokyo Transit Gateway가 배포되어 있어야 함 (Tokyo 모듈에서 생성)
- 두 리전 모두에 AWS Provider 접근 권한 필요

## Import 기존 리소스 (필요 시)

```bash
# Peering Attachment
terraform import aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo <ATTACHMENT_ID>

# Peering Accepter
terraform import aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept <ATTACHMENT_ID>

# Routes
terraform import aws_ec2_transit_gateway_route.seoul_to_tokyo_aws <ROUTE_TABLE_ID>_40.0.0.0/16
terraform import aws_ec2_transit_gateway_route.seoul_to_tokyo_idc <ROUTE_TABLE_ID>_30.0.0.0/16
terraform import aws_ec2_transit_gateway_route.tokyo_to_seoul_aws <ROUTE_TABLE_ID>_20.0.0.0/16
terraform import aws_ec2_transit_gateway_route.tokyo_to_seoul_idc <ROUTE_TABLE_ID>_10.0.0.0/16
```

## 연결 테스트

### Seoul → Tokyo 연결 확인
```bash
# Seoul Beanstalk 인스턴스에서
ping 40.0.1.10  # Tokyo VPC 내부 IP
ping 30.0.1.10  # Tokyo IDC 내부 IP
```

### Tokyo → Seoul 연결 확인
```bash
# Tokyo Beanstalk 인스턴스에서
ping 20.0.1.10  # Seoul VPC 내부 IP
ping 10.0.1.10  # Seoul IDC 내부 IP
```
