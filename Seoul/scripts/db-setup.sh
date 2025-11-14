#!/bin/bash
# MySQL 8.0 Installation Script for IDC DB Instance

set -e

echo "=== MySQL 8.0 Installation Started ==="

# MySQL 8.0 설치
dnf update -y
dnf install -y mysql-server

# MySQL 서비스 시작 및 자동 시작 활성화
systemctl start mysqld
systemctl enable mysqld

# MySQL root 비밀번호 설정 및 데이터베이스 초기화
mysql -u root <<-MYSQL
  ALTER USER 'root'@'localhost' IDENTIFIED BY 'Password123!';
  CREATE DATABASE IF NOT EXISTS idcdb;
  CREATE USER IF NOT EXISTS 'idcuser'@'%' IDENTIFIED BY 'Password123!';
  GRANT ALL PRIVILEGES ON idcdb.* TO 'idcuser'@'%';
  FLUSH PRIVILEGES;
MYSQL

# 원격 접속 허용
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/my.cnf.d/mysql-server.cnf
systemctl restart mysqld

echo "=== MySQL 8.0 Installation Completed ==="
echo "Database: idcdb"
echo "User: idcuser"
echo "Password: Password123!"
