#!/bin/bash
# AWS Managed VPN 자동 설정 스크립트
# IDC Customer Gateway EC2 인스턴스용

set -e

echo "=== VPN 설정 시작 ==="

# 변수 설정 (Terraform에서 주입)
TUNNEL1_OUTSIDE="${tunnel1_address}"
TUNNEL2_OUTSIDE="${tunnel2_address}"
TUNNEL1_PSK="${tunnel1_psk}"
TUNNEL2_PSK="${tunnel2_psk}"
LOCAL_CIDR="${local_cidr}"
REMOTE_CIDR="${remote_cidr}"
TOKYO_AWS_CIDR="${tokyo_aws_cidr}"
TOKYO_IDC_CIDR="${tokyo_idc_cidr}"

# IP 포워딩 활성화
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Libreswan 및 iptables 설치
yum update -y
yum install -y libreswan iptables-services

# Libreswan 메인 설정 파일에 include 추가
echo "include /etc/ipsec.d/*.conf" >> /etc/ipsec.conf

# Libreswan 설정 파일 생성 (AWS IKEv2 기반 - 모든 AWS 네트워크 포함)
cat > /etc/ipsec.d/aws-vpn.conf <<CONF
conn tunnel1
    authby=secret
    auto=start
    left=%defaultroute
    leftid=%any
    leftsubnet=$LOCAL_CIDR
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

conn tunnel2
    authby=secret
    auto=start
    left=%defaultroute
    leftid=%any
    leftsubnet=$LOCAL_CIDR
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
CONF

# PSK 설정 (각 터널별로 매칭)
cat > /etc/ipsec.d/aws-vpn.secrets <<SECRETS
$TUNNEL1_OUTSIDE %any : PSK "$TUNNEL1_PSK"
$TUNNEL2_OUTSIDE %any : PSK "$TUNNEL2_PSK"
SECRETS
chmod 600 /etc/ipsec.d/aws-vpn.secrets

# iptables 설정
systemctl enable iptables
systemctl start iptables

# 기존 FORWARD 규칙 초기화
iptables -F FORWARD

# FORWARD 체인 기본 정책을 ACCEPT로 설정
iptables -P FORWARD ACCEPT

# NAT 설정
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# FORWARD 규칙: VPN 트래픽 양방향 허용
iptables -I FORWARD 1 -s $LOCAL_CIDR -d $REMOTE_CIDR -j ACCEPT
iptables -I FORWARD 2 -s $REMOTE_CIDR -d $LOCAL_CIDR -j ACCEPT

# Tokyo AWS/IDC와의 트래픽 허용
iptables -I FORWARD 3 -s $LOCAL_CIDR -d $TOKYO_AWS_CIDR -j ACCEPT
iptables -I FORWARD 4 -s $TOKYO_AWS_CIDR -d $LOCAL_CIDR -j ACCEPT
iptables -I FORWARD 5 -s $LOCAL_CIDR -d $TOKYO_IDC_CIDR -j ACCEPT
iptables -I FORWARD 6 -s $TOKYO_IDC_CIDR -d $LOCAL_CIDR -j ACCEPT

service iptables save

# Libreswan 시작
systemctl enable ipsec
systemctl start ipsec

# 설정 완료 후 상태 확인 (30초 대기)
sleep 30
ipsec status

echo "=== VPN 설정 완료 ==="