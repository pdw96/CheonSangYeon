# Global VPC - 동적 라우팅 가이드

## 개요
이 문서는 global/vpc에서 관리하는 IDC Private Route Table의 동적 라우팅 구성을 설명합니다.

## 라우팅 구조

### Seoul IDC Private Route Table (rtb-0a835c94cb2feba95)
Seoul IDC Private DB 서브넷(10.0.2.0/24)에서 다른 VPC로 가는 라우팅 규칙:

| 목적지 CIDR | 네트워크 인터페이스 | 설명 |
|------------|-------------------|------|
| 10.0.0.0/16 | local | Seoul IDC VPC 내부 통신 |
| 20.0.0.0/16 | eni-012ce5ca163dba144 | Seoul AWS VPC (CGW를 통한 라우팅) |
| 30.0.0.0/16 | eni-012ce5ca163dba144 | Tokyo IDC VPC (CGW를 통한 라우팅) |
| 40.0.0.0/16 | eni-012ce5ca163dba144 | Tokyo AWS VPC (CGW를 통한 라우팅) |

### Tokyo IDC Private Route Table (rtb-0089d3c0cd081488d)
Tokyo IDC Private DB 서브넷(30.0.2.0/24)에서 다른 VPC로 가는 라우팅 규칙:

| 목적지 CIDR | 네트워크 인터페이스 | 설명 |
|------------|-------------------|------|
| 30.0.0.0/16 | local | Tokyo IDC VPC 내부 통신 |
| 10.0.0.0/16 | eni-0ee5f634352945b1b | Seoul IDC VPC (CGW를 통한 라우팅) |
| 20.0.0.0/16 | eni-0ee5f634352945b1b | Seoul AWS VPC (CGW를 통한 라우팅) |
| 40.0.0.0/16 | eni-0ee5f634352945b1b | Tokyo AWS VPC (CGW를 통한 라우팅) |

## 네트워크 인터페이스 (ENI)

### Seoul CGW ENI
- **ENI ID**: eni-012ce5ca163dba144
- **인스턴스**: i-0a7fa5e0758c1e0f0 (Seoul IDC CGW)
- **역할**: Seoul IDC에서 다른 모든 VPC로 트래픽 라우팅

### Tokyo CGW ENI
- **ENI ID**: eni-0ee5f634352945b1b
- **인스턴스**: i-0aae03aa15370da41 (Tokyo IDC CGW)
- **역할**: Tokyo IDC에서 다른 모든 VPC로 트래픽 라우팅

## Terraform 변수 관리

### terraform.tfvars
CGW 네트워크 인터페이스 ID를 `terraform.tfvars` 파일에서 관리합니다:

```hcl
# CGW Network Interface IDs
seoul_cgw_network_interface_id = "eni-012ce5ca163dba144"
tokyo_cgw_network_interface_id = "eni-0ee5f634352945b1b"
```

### 변수 업데이트 방법
1. Seoul 또는 Tokyo에서 새로운 CGW 인스턴스를 배포한 경우
2. `module.idc.cgw_network_interface_id` output을 확인
3. `global/vpc/terraform.tfvars` 파일의 해당 변수를 업데이트
4. `terraform plan`으로 변경 사항 확인
5. `terraform apply`로 라우팅 규칙 업데이트

## Route 리소스 구조

### Seoul IDC Routes
```hcl
resource "aws_route" "seoul_idc_to_seoul_aws" {
  provider               = aws.seoul
  route_table_id         = aws_route_table.seoul_idc_private.id
  destination_cidr_block = var.seoul_vpc_cidr  # 20.0.0.0/16
  network_interface_id   = var.seoul_cgw_network_interface_id
  count = var.seoul_cgw_network_interface_id != "" ? 1 : 0
}

resource "aws_route" "seoul_idc_to_tokyo_idc" {
  provider               = aws.seoul
  route_table_id         = aws_route_table.seoul_idc_private.id
  destination_cidr_block = var.tokyo_idc_vpc_cidr  # 30.0.0.0/16
  network_interface_id   = var.seoul_cgw_network_interface_id
  count = var.seoul_cgw_network_interface_id != "" ? 1 : 0
}

resource "aws_route" "seoul_idc_to_tokyo_aws" {
  provider               = aws.seoul
  route_table_id         = aws_route_table.seoul_idc_private.id
  destination_cidr_block = var.tokyo_vpc_cidr  # 40.0.0.0/16
  network_interface_id   = var.seoul_cgw_network_interface_id
  count = var.seoul_cgw_network_interface_id != "" ? 1 : 0
}
```

### Tokyo IDC Routes
```hcl
resource "aws_route" "tokyo_idc_to_seoul_idc" {
  provider               = aws.tokyo
  route_table_id         = aws_route_table.tokyo_idc_private.id
  destination_cidr_block = var.seoul_idc_vpc_cidr  # 10.0.0.0/16
  network_interface_id   = var.tokyo_cgw_network_interface_id
  count = var.tokyo_cgw_network_interface_id != "" ? 1 : 0
}

resource "aws_route" "tokyo_idc_to_seoul_aws" {
  provider               = aws.tokyo
  route_table_id         = aws_route_table.tokyo_idc_private.id
  destination_cidr_block = var.seoul_vpc_cidr  # 20.0.0.0/16
  network_interface_id   = var.tokyo_cgw_network_interface_id
  count = var.tokyo_cgw_network_interface_id != "" ? 1 : 0
}

resource "aws_route" "tokyo_idc_to_tokyo_aws" {
  provider               = aws.tokyo
  route_table_id         = aws_route_table.tokyo_idc_private.id
  destination_cidr_block = var.tokyo_vpc_cidr  # 40.0.0.0/16
  network_interface_id   = var.tokyo_cgw_network_interface_id
  count = var.tokyo_cgw_network_interface_id != "" ? 1 : 0
}
```

## 라우팅 테스트

### Seoul IDC DB에서 다른 VPC로 연결 테스트
```bash
# Seoul IDC DB 인스턴스에 SSH 접속
ssh -i your-key.pem ec2-user@10.0.2.89

# Seoul AWS VPC로 핑 테스트
ping 20.0.1.1

# Tokyo IDC VPC로 핑 테스트
ping 30.0.1.1

# Tokyo AWS VPC로 핑 테스트
ping 40.0.1.1
```

### Tokyo IDC DB에서 다른 VPC로 연결 테스트
```bash
# Tokyo IDC DB 인스턴스에 SSH 접속
ssh -i your-key.pem ec2-user@30.0.2.241

# Seoul IDC VPC로 핑 테스트
ping 10.0.1.1

# Seoul AWS VPC로 핑 테스트
ping 20.0.1.1

# Tokyo AWS VPC로 핑 테스트
ping 40.0.1.1
```

## 트러블슈팅

### Route가 생성되지 않는 경우
1. `terraform.tfvars`에 CGW ENI ID가 올바르게 설정되어 있는지 확인
2. ENI가 실제로 존재하고 활성 상태인지 AWS 콘솔에서 확인
3. `terraform plan`으로 Route 리소스가 생성될 예정인지 확인

### 라우팅이 작동하지 않는 경우
1. CGW 인스턴스의 VPN 설정이 올바른지 확인
2. Security Group에서 ICMP 및 필요한 프로토콜이 허용되어 있는지 확인
3. Route Table Association이 올바른 서브넷에 연결되어 있는지 확인

## 관련 리소스
- Seoul CGW 인스턴스: `Seoul/modules/idc`
- Tokyo CGW 인스턴스: `Tokyo/modules/idc`
- VPC 중앙 관리: `global/vpc/main.tf`
- 서브넷 구성: `global/vpc/README.md` (생성 예정)
