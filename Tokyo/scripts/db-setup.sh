#!/bin/bash
# MySQL 8.0 Installation Script for IDC DB Instance

set -euo pipefail

DB_ROOT_SECRET_ARN="${DB_ROOT_SECRET_ARN:-"${db_root_secret_arn}"}"
DB_APP_SECRET_ARN="${DB_APP_SECRET_ARN:-"${db_app_secret_arn}"}"
DB_SECRET_REGION="${DB_SECRET_REGION:-"${db_secret_region}"}"
DB_APP_USERNAME="${DB_APP_USERNAME:-"${db_app_username}"}"

if [[ -z "$DB_SECRET_REGION" ]]; then
  DB_SECRET_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
fi

if [[ -z "$DB_ROOT_SECRET_ARN" || -z "$DB_APP_SECRET_ARN" || -z "$DB_SECRET_REGION" || -z "$DB_APP_USERNAME" ]]; then
  echo "[ERROR] Required database secret metadata is missing" >&2
  exit 1
fi

fetch_secret() {
  local secret_arn="$1"
  local region="$2"
  aws secretsmanager get-secret-value \
    --secret-id "$secret_arn" \
    --region "$region" \
    --query 'SecretString' \
    --output text
}

DB_ROOT_PASSWORD="$(fetch_secret "$DB_ROOT_SECRET_ARN" "$DB_SECRET_REGION")"
DB_APP_PASSWORD="$(fetch_secret "$DB_APP_SECRET_ARN" "$DB_SECRET_REGION")"

if [[ -z "$DB_ROOT_PASSWORD" || -z "$DB_APP_PASSWORD" ]]; then
  echo "[ERROR] Failed to retrieve database secrets" >&2
  exit 1
fi

echo "=== MySQL 8.0 Installation Started ==="

# MySQL 8.0 설치
dnf update -y >/dev/null
dnf install -y mysql-server >/dev/null

# MySQL 서비스 시작 및 자동 시작 활성화
systemctl start mysqld
systemctl enable mysqld

# MySQL root 비밀번호 설정 및 데이터베이스 초기화
mysql -u root <<-MYSQL
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
  CREATE DATABASE IF NOT EXISTS idcdb;
  CREATE USER IF NOT EXISTS '${DB_APP_USERNAME}'@'%' IDENTIFIED BY '${DB_APP_PASSWORD}';
  GRANT ALL PRIVILEGES ON idcdb.* TO '${DB_APP_USERNAME}'@'%';
  FLUSH PRIVILEGES;
MYSQL

# 원격 접속 허용
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/my.cnf.d/mysql-server.cnf
systemctl restart mysqld

echo "=== MySQL 8.0 Installation Completed ==="
echo "Database: idcdb"
echo "User: ${DB_APP_USERNAME}"
echo "Password stored securely in Secrets Manager (ARN: $DB_APP_SECRET_ARN)"
