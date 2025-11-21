#!/bin/bash
# AWS Managed VPN 자동 구성 스크립트 (Libreswan - AL2023)
# IDC Customer Gateway EC2 인스턴스에서 실행

set -e

echo "=== VPN 구성 시작 (Libreswan) ==="

# Terraform에서 넘어오는 값
TUNNEL1_OUTSIDE="${tunnel1_address}"
TUNNEL2_OUTSIDE="${tunnel2_address}"
TUNNEL1_PSK="${tunnel1_psk}"
TUNNEL2_PSK="${tunnel2_psk}"
LOCAL_CIDR="${local_cidr}"
REMOTE_CIDR="${remote_cidr}"
TOKYO_AWS_CIDR="${tokyo_aws_cidr}"
TOKYO_IDC_CIDR="${tokyo_idc_cidr}"

# IP 포워딩 활성화 (중복 추가 방지)
if ! grep -q "^net.ipv4.ip_forward *= *1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi
sysctl -p

# 패키지 설치 (Amazon Linux 2023)
yum update -y
yum install -y libreswan iptables-services

# Libreswan 설정 파일 작성
cat > /etc/ipsec.d/aws-vpn.conf <<CONF
conn tunnel1
    authby=secret
    auto=start
    left=%defaultroute
    leftid=%any
    leftsubnet=0.0.0.0/0
    right=$TUNNEL1_OUTSIDE
    rightsubnet=0.0.0.0/0
    type=tunnel
    ikev2=insist
    ike=aes128-sha1-modp2048
    phase2alg=aes128-sha1-modp2048
    ikelifetime=28800s
    salifetime=3600s
    dpddelay=10s
    dpdtimeout=30s
    dpdaction=restart
    mark=100/0xffffffff
    vti-interface=vti1
    vti-routing=no
    vti-shared=no

conn tunnel2
    authby=secret
    auto=start
    left=%defaultroute
    leftid=%any
    leftsubnet=0.0.0.0/0
    right=$TUNNEL2_OUTSIDE
    rightsubnet=0.0.0.0/0
    type=tunnel
    ikev2=insist
    ike=aes128-sha1-modp2048
    phase2alg=aes128-sha1-modp2048
    ikelifetime=28800s
    salifetime=3600s
    dpddelay=10s
    dpdtimeout=30s
    dpdaction=restart
    mark=200/0xffffffff
    vti-interface=vti2
    vti-routing=no
    vti-shared=no
CONF

# PSK 설정
cat > /etc/ipsec.d/aws-vpn.secrets <<SECRETS
$TUNNEL1_OUTSIDE %any : PSK "$TUNNEL1_PSK"
$TUNNEL2_OUTSIDE %any : PSK "$TUNNEL2_PSK"
SECRETS
chmod 600 /etc/ipsec.d/aws-vpn.secrets

# iptables 초기화 및 규칙 구성
systemctl enable iptables
systemctl start iptables

iptables -F FORWARD
iptables -t nat -F
iptables -P FORWARD ACCEPT

iptables -t nat -A POSTROUTING -s $REMOTE_CIDR -d $LOCAL_CIDR -j MASQUERADE
if [[ -n "$TOKYO_AWS_CIDR" && "$TOKYO_AWS_CIDR" != "null" ]]; then
  iptables -t nat -A POSTROUTING -s $TOKYO_AWS_CIDR -d $LOCAL_CIDR -j MASQUERADE
fi
if [[ -n "$TOKYO_IDC_CIDR" && "$TOKYO_IDC_CIDR" != "null" ]]; then
  iptables -t nat -A POSTROUTING -s $TOKYO_IDC_CIDR -d $LOCAL_CIDR -j MASQUERADE
fi
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

iptables -I FORWARD 1 -s $LOCAL_CIDR -d $REMOTE_CIDR -j ACCEPT
iptables -I FORWARD 2 -s $REMOTE_CIDR -d $LOCAL_CIDR -j ACCEPT
if [[ -n "$TOKYO_AWS_CIDR" && "$TOKYO_AWS_CIDR" != "null" ]]; then
  iptables -I FORWARD 3 -s $LOCAL_CIDR -d $TOKYO_AWS_CIDR -j ACCEPT
  iptables -I FORWARD 4 -s $TOKYO_AWS_CIDR -d $LOCAL_CIDR -j ACCEPT
fi
if [[ -n "$TOKYO_IDC_CIDR" && "$TOKYO_IDC_CIDR" != "null" ]]; then
  iptables -I FORWARD 5 -s $LOCAL_CIDR -d $TOKYO_IDC_CIDR -j ACCEPT
  iptables -I FORWARD 6 -s $TOKYO_IDC_CIDR -d $LOCAL_CIDR -j ACCEPT
fi

iptables-save > /etc/sysconfig/iptables

# Libreswan 시작 (VTI 모드)
systemctl enable ipsec
systemctl start ipsec

# VTI 인터페이스 설정 대기
sleep 10

# VTI 인터페이스 활성화 및 라우팅 설정
ip link set vti1 up 2>/dev/null || true
ip link set vti2 up 2>/dev/null || true

# VTI를 통한 라우팅 설정 (Primary: vti1, Backup: vti2)
ip route add $REMOTE_CIDR dev vti1 metric 100 2>/dev/null || true
ip route add $REMOTE_CIDR dev vti2 metric 200 2>/dev/null || true

if [[ -n "$TOKYO_AWS_CIDR" && "$TOKYO_AWS_CIDR" != "null" ]]; then
  ip route add $TOKYO_AWS_CIDR dev vti1 metric 100 2>/dev/null || true
  ip route add $TOKYO_AWS_CIDR dev vti2 metric 200 2>/dev/null || true
fi

if [[ -n "$TOKYO_IDC_CIDR" && "$TOKYO_IDC_CIDR" != "null" ]]; then
  ip route add $TOKYO_IDC_CIDR dev vti1 metric 100 2>/dev/null || true
  ip route add $TOKYO_IDC_CIDR dev vti2 metric 200 2>/dev/null || true
fi

# IPsec 연결 확인
ipsec status | grep -i "STATE" || true

sleep 10
ipsec trafficstatus

echo "=== VPN 구성 완료 (Libreswan VTI) ==="
