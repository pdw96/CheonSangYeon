#!/bin/bash
# MySQL 8.0 Installation Script for IDC DB Instance (Amazon Linux 2023)

set -e

echo "=== MySQL 8.0 Installation Started ==="

# Amazon Linux 2023에서 MySQL 8.0 Community Server 설치
dnf install -y mariadb105-server

# MariaDB 서비스 시작 및 자동 시작 활성화
systemctl start mariadb
systemctl enable mariadb

# MariaDB root 비밀번호 설정 및 데이터베이스 초기화
mysql -u root <<-MYSQL
  ALTER USER 'root'@'localhost' IDENTIFIED BY 'Password123!';
  CREATE DATABASE IF NOT EXISTS idcdb;
  CREATE USER IF NOT EXISTS 'idcuser'@'%' IDENTIFIED BY 'Password123!';
  GRANT ALL PRIVILEGES ON idcdb.* TO 'idcuser'@'%';
  FLUSH PRIVILEGES;
MYSQL

# 원격 접속 허용 - MariaDB가 0.0.0.0에서 리스닝하도록 강제 설정
echo "Configuring MariaDB for remote access..."
# /etc/my.cnf.d/mariadb-server.cnf 파일에 bind-address 설정
cat > /etc/my.cnf.d/mariadb-server.cnf <<'EOF'
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mariadb/mariadb.log
pid-file=/run/mariadb/mariadb.pid
bind-address = 0.0.0.0
EOF

echo "Restarting MariaDB service..."
systemctl restart mariadb
sleep 3
echo "MariaDB restarted successfully"
echo "Checking MariaDB listening port..."
ss -tlnp | grep 3306 || echo "WARNING: MariaDB may not be listening on port 3306"

# Static route 추가 - Seoul VPC로 가는 트래픽을 CGW를 통하도록 설정
# CGW IP를 동적으로 조회 (같은 서브넷에서 idc-cgw 태그를 가진 인스턴스)
CGW_IP=$(aws ec2 describe-instances \
  --region ap-northeast-2 \
  --filters "Name=tag:Name,Values=idc-cgw-instance" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)

echo "CGW IP detected: $CGW_IP"

# AWS VPC CIDR로 가는 트래픽을 CGW를 통하도록 라우팅
ip route add 20.0.0.0/16 via $CGW_IP
ip route add 30.0.0.0/16 via $CGW_IP
ip route add 40.0.0.0/16 via $CGW_IP

# 재부팅 후에도 유지되도록 설정
cat > /etc/sysconfig/network-scripts/route-eth0 <<EOF
20.0.0.0/16 via $CGW_IP
30.0.0.0/16 via $CGW_IP
40.0.0.0/16 via $CGW_IP
EOF

echo "=== MySQL/MariaDB Installation Completed ==="
echo "Database: idcdb"
echo "User: idcuser"
echo "Password: Password123!"

# 테이블 생성 및 데이터 삽입 (자동화)
mysql -u idcuser -pPassword123! idcdb <<-MYSQL
CREATE TABLE IF NOT EXISTS userTBL
( 
userID CHAR(8) NOT NULL PRIMARY KEY,
name NVARCHAR(10) NOT NULL,
birthYear INT NOT NULL,
addr NCHAR(2) NOT NULL,
mobile1 CHAR(3),
mobile2 CHAR(8),
height SMALLINT,
mDATE DATE
);

INSERT IGNORE INTO userTBL VALUES ('LSG', '이승기', 1987, '서울', '011', '1111111', 182, '2008-8-8');
INSERT IGNORE INTO userTBL VALUES ('KBS', '김범수', 1979, '경남', '011', '2222222', 173, '2012-4-4');
INSERT IGNORE INTO userTBL VALUES ('KKH', '김경호', 1971, '전남', '019', '3333333', 177, '2007-7-7');
INSERT IGNORE INTO userTBL VALUES ('JYP', '조용필', 1950, '경기', '011', '4444444', 166, '2009-4-4');
INSERT IGNORE INTO userTBL VALUES ('SSK', '성시경', 1979, '서울', NULL, NULL, 186, '2013-12-12');
INSERT IGNORE INTO userTBL VALUES ('LJB', '임재범', 1963, '서울', '016', '6666666', 182, '2009-9-9');
INSERT IGNORE INTO userTBL VALUES ('YJS', '윤종신', 1969, '경남', NULL, NULL, 170, '2005-5-5');
INSERT IGNORE INTO userTBL VALUES ('EJW', '은지원', 1972, '경북', '011', '8888888', 174, '2014-3-3');
INSERT IGNORE INTO userTBL VALUES ('JKW', '조관우', 1965, '경기', '018', '9999999', 172, '2010-10-10');
INSERT IGNORE INTO userTBL VALUES ('BBK', '바비킴', 1973, '서울', '010', '0000000', 176, '2013-5-5');
INSERT IGNORE INTO userTBL VALUES ('JUL', '김주일', 1978, '서울', '010', '0000000', 176, '2013-5-5');
INSERT IGNORE INTO userTBL VALUES ('CSJ', '최소진', 1986, '서울', '010', '0000000', 176, '2013-5-5');
MYSQL

echo "=== Sample Data Inserted ==="
