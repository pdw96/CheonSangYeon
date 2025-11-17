# Transit Gateway Peering

Seoul과 Tokyo 리전 간 Transit Gateway Peering 구성

## 아키텍처

```
Seoul TGW (tgw-0a4103ee0020eff4e)
    ↕ Peering (tgw-attach-08dd381f1167b409b)
Tokyo TGW (tgw-0e65a88096c497691)
```

## 라우팅

**Seoul TGW Routes:**
- `40.0.0.0/16` → Tokyo AWS VPC
- `30.0.0.0/16` → Tokyo IDC VPC

**Tokyo TGW Routes:**
- `20.0.0.0/16` → Seoul AWS VPC
- `10.0.0.0/16` → Seoul IDC VPC

## 배포

```bash
cd global/tgw-peering
terraform init
terraform plan
terraform apply
```

## Import 기존 리소스

```bash
# Peering Attachment
terraform import aws_ec2_transit_gateway_peering_attachment.seoul_to_tokyo tgw-attach-08dd381f1167b409b

# Peering Accepter
terraform import aws_ec2_transit_gateway_peering_attachment_accepter.tokyo_accept tgw-attach-08dd381f1167b409b

# Routes
terraform import aws_ec2_transit_gateway_route.seoul_to_tokyo_aws tgw-rtb-0f8b0f1fc2c385b52_40.0.0.0/16
terraform import aws_ec2_transit_gateway_route.seoul_to_tokyo_idc tgw-rtb-0f8b0f1fc2c385b52_30.0.0.0/16
terraform import aws_ec2_transit_gateway_route.tokyo_to_seoul_aws tgw-rtb-0d49ed6c6cf5c8a95_20.0.0.0/16
terraform import aws_ec2_transit_gateway_route.tokyo_to_seoul_idc tgw-rtb-0d49ed6c6cf5c8a95_10.0.0.0/16
```

## 전제 조건

- Seoul Transit Gateway가 배포되어 있어야 함
- Tokyo Transit Gateway가 배포되어 있어야 함
- 두 리전 모두에 AWS Provider 접근 권한 필요
