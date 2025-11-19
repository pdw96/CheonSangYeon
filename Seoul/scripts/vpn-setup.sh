#!/bin/bash
# AWS Managed VPN 자동 구성 스크립트 (Strongswan)
# IDC Customer Gateway EC2 인스턴스에서 실행

set -e

echo "=== VPN 구성 시작 (Strongswan) ==="

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

# 패키지 설치 (Amazon Linux 2023 기준 dnf 사용)
dnf update -y
dnf install -y strongswan iptables-services

# Strongswan 설정 파일 작성 (AWS 권장 파라미터)
cat > /etc/strongswan/ipsec.conf <<CONF
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"

conn %default
    ikelifetime=28800s
    keylife=3600s
    rekeymargin=540s
    keyingtries=%forever
    keyexchange=ikev2
    mobike=no
    ike=aes128-sha1-modp2048!
    esp=aes128-sha1-modp2048!

conn tunnel1
    auto=start
    left=%defaultroute
    leftid=%any
    leftsubnet=$LOCAL_CIDR
    right=$TUNNEL1_OUTSIDE
    rightsubnet=0.0.0.0/0
    authby=secret
    type=tunnel
    dpdaction=restart
    closeaction=restart
    dpddelay=10s
    dpdtimeout=30s

conn tunnel2
    auto=start
    left=%defaultroute
    leftid=%any
    leftsubnet=$LOCAL_CIDR
    right=$TUNNEL2_OUTSIDE
    rightsubnet=0.0.0.0/0
    authby=secret
    type=tunnel
    dpdaction=restart
    closeaction=restart
    dpddelay=10s
    dpdtimeout=30s
CONF

# PSK 설정
cat > /etc/strongswan/ipsec.secrets <<SECRETS
%any $TUNNEL1_OUTSIDE : PSK "$TUNNEL1_PSK"
%any $TUNNEL2_OUTSIDE : PSK "$TUNNEL2_PSK"
SECRETS
chmod 600 /etc/strongswan/ipsec.secrets

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

# Strongswan 서비스 재시작
systemctl enable strongswan
systemctl restart strongswan

sleep 30
strongswan status

echo "=== VPN 구성 완료 (Strongswan) ==="
