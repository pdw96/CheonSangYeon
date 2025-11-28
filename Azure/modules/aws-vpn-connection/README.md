# AWS VPN Connection Module

This module creates AWS Site-to-Site VPN connection from Seoul Transit Gateway to Azure VPN Gateway.

## Purpose

Azure 배포 시 AWS와의 VPN 연결을 자동으로 구성하여 하이브리드 클라우드 환경을 완성합니다.

## Architecture

```
Azure VNet (50.0.0.0/16)
    ↓
Azure VPN Gateway (Public IP)
    ↓↑ (IPsec Tunnel)
AWS Customer Gateway
    ↓
AWS VPN Connection
    ↓
AWS Transit Gateway
    ↓
Seoul VPC (20.0.0.0/16)
```

## Features

- **Automatic VPN Setup**: Azure 배포 시 AWS VPN 자동 구성
- **Transit Gateway Integration**: Seoul Transit Gateway와 연동
- **Azure-Compatible IPsec**: Azure VPN Gateway와 호환되는 IPsec 설정
- **Dual Tunnel**: 고가용성을 위한 Tunnel 1, Tunnel 2 구성
- **Static Routing**: Azure VPN Gateway와의 호환성을 위한 Static Routes

## Prerequisites

1. **Seoul Module Deployed**: Seoul Terraform state must be available
2. **Azure VPN Gateway**: Azure VPN Gateway must be created first
3. **Shared Key**: Strong pre-shared key for VPN authentication

## IPsec Parameters

- **IKE Version**: IKEv2
- **Phase 1 Encryption**: AES256
- **Phase 1 Integrity**: SHA2-256
- **Phase 1 DH Group**: Group 14
- **Phase 2 Encryption**: AES256
- **Phase 2 Integrity**: SHA2-256
- **Phase 2 DH Group**: Group 14
- **DPD Timeout**: 30 seconds

## Usage in Azure Module

```hcl
module "aws_vpn_connection" {
  source = "./modules/aws-vpn-connection"
  
  providers = {
    aws = aws.seoul
  }
  
  # Seoul State 정보
  seoul_state_bucket = var.seoul_state_bucket
  seoul_state_key    = "seoul/terraform.tfstate"
  
  # Azure VPN Gateway 정보
  azure_vpn_gateway_ip = azurerm_public_ip.vpn_gateway.ip_address
  azure_bgp_asn        = 65515
  azure_vnet_cidr      = "50.0.0.0/16"
  azure_vpn_shared_key = var.azure_vpn_shared_key
  
  depends_on = [
    azurerm_virtual_network_gateway.vpn_gateway
  ]
}
```

## Required Seoul Module Outputs

Seoul 모듈에서 다음 outputs가 필요합니다:

```hcl
output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_route_table_id" {
  description = "Transit Gateway Default Route Table ID"
  value       = aws_ec2_transit_gateway.main.association_default_route_table_id
}

output "private_route_table_id" {
  description = "Seoul Private Route Table ID"
  value       = aws_route_table.seoul_private.id
}
```

## Outputs

- `customer_gateway_id`: AWS Customer Gateway ID
- `vpn_connection_id`: VPN Connection ID
- `tunnel_1_address`: AWS Tunnel 1 Outside IP
- `tunnel_2_address`: AWS Tunnel 2 Outside IP
- `tunnel_1_psk`: Tunnel 1 Pre-Shared Key (민감)
- `tunnel_2_psk`: Tunnel 2 Pre-Shared Key (민감)
- `transit_gateway_attachment_id`: TGW Attachment ID
- `vpn_setup_guide`: Azure 측 설정 가이드

## Post-Deployment: Azure Configuration

### 1. Local Network Gateway 생성/업데이트

```bash
az network local-gateway create \
  --name aws-seoul-lng \
  --resource-group <YOUR_RG> \
  --gateway-ip-address <TUNNEL_1_ADDRESS> \
  --local-address-prefixes 20.0.0.0/16 \
  --location koreacentral
```

### 2. VPN Connection 생성

```bash
az network vpn-connection create \
  --name aws-azure-vpn-connection \
  --resource-group <YOUR_RG> \
  --vnet-gateway1 <VPN_GATEWAY_NAME> \
  --local-gateway2 aws-seoul-lng \
  --shared-key "<SHARED_KEY>" \
  --location koreacentral
```

### 3. 연결 확인

```bash
# Azure 측 상태 확인
az network vpn-connection show \
  --name aws-azure-vpn-connection \
  --resource-group <YOUR_RG> \
  --query connectionStatus

# AWS 측 상태 확인 (AWS Console)
# VPC > Site-to-Site VPN Connections > seoul-to-azure-vpn
```

## Security Considerations

1. **Shared Key Management**:
   - 환경 변수로 관리: `TF_VAR_azure_vpn_shared_key`
   - Key Vault/Secrets Manager 사용 권장
   - 강력한 키 생성 (최소 32자, 특수문자 포함)

2. **IPsec Configuration**:
   - Azure VPN Gateway 호환 설정 사용
   - 강력한 암호화 알고리즘 (AES256, SHA2-256)
   - Perfect Forward Secrecy (DH Group 14)

3. **Network Segmentation**:
   - Seoul VPC: 20.0.0.0/16
   - Azure VNet: 50.0.0.0/16
   - CIDR 충돌 방지

## Troubleshooting

### VPN 연결 실패

1. **Pre-Shared Key 확인**:
   ```bash
   terraform output -raw tunnel_1_psk
   ```

2. **Azure VPN Gateway 상태**:
   ```bash
   az network vnet-gateway show \
     --name <VPN_GATEWAY_NAME> \
     --resource-group <YOUR_RG> \
     --query provisioningState
   ```

3. **AWS VPN Connection 상태**:
   - AWS Console > VPC > Site-to-Site VPN Connections
   - Status: "Available" 확인

### Tunnel Down

1. **IPsec 설정 확인**: 양측 설정 일치 여부
2. **Firewall Rules**: UDP 500, 4500 허용
3. **DPD Timeout**: 30초 설정 확인

## Cost Estimation

- **AWS VPN Connection**: ~$0.05/hour (~$36/month)
- **Data Transfer**: Outbound 데이터 전송 비용 별도
- **Transit Gateway Attachment**: VPN attachment 포함

## References

- [AWS VPN Connection](https://docs.aws.amazon.com/vpn/latest/s2svpn/VPC_VPN.html)
- [Azure VPN Gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/)
- [IPsec/IKE Parameters](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-devices)
