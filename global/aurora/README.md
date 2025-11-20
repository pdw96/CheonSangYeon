# Aurora Global Database (MySQL 8.0)

Aurora Global Database를 서울 리전에 Primary로 배포하고, IDC MySQL 데이터를 마이그레이션합니다.

## 아키텍처

### Global Cluster
- **Engine**: Aurora MySQL 8.0 (8.0.mysql_aurora.3.04.0)
- **Primary Region**: Seoul (ap-northeast-2)
- **Secondary Region**: Tokyo (ap-northeast-1)
- **Storage**: 암호화 활성화

### Seoul Primary Cluster
- **인스턴스 타입**: db.r5.large
- **Writer**: 1개 (읽기/쓰기)
- **Reader**: 1개 (읽기 전용, HA)
- **백업**: 7일 보존, S3 통합
- **모니터링**: CloudWatch + Performance Insights

### Tokyo Secondary Cluster
- **인스턴스 타입**: db.r5.large
- **Reader**: 1개 (읽기 전용, DR)
- **용도**: 재해 복구, 글로벌 읽기 성능 향상

### S3 통합
- **Terraform State Backend**: S3 버킷 사용
- **데이터 백업**: S3로 자동 백업
- **마이그레이션**: IDC MySQL → S3 → Aurora

## 배포 순서

### 1. S3 버킷 먼저 생성
```bash
cd global/s3
terraform init
terraform apply
```

### 2. Account ID 확인 및 Backend 설정
```bash
# Account ID 확인
aws sts get-caller-identity --query Account --output text

# backend.tfvars 파일에서 YOUR_ACCOUNT_ID를 실제 계정 ID로 변경
# 예: bucket = "aurora-global-db-backup-123456789012"
```

### 3. Aurora 배포
```bash
cd global/aurora

# Backend 설정과 함께 초기화
terraform init -backend-config=backend.tfvars

# 또는 직접 지정
terraform init \
  -backend-config="bucket=aurora-global-db-backup-123456789012" \
  -backend-config="key=terraform/aurora-global/terraform.tfstate" \
  -backend-config="region=ap-northeast-2" \
  -backend-config="encrypt=true"

terraform apply
```

## IDC MySQL → Aurora 마이그레이션

### 방법 1: mysqldump 사용
```bash
# IDC DB 인스턴스 접속
ssh -i your-key.pem ec2-user@<IDC_DB_IP>

# 데이터 덤프
mysqldump -h localhost -u idcuser -p'Password123!' idcdb > /tmp/idcdb_backup.sql

# S3에 업로드
aws s3 cp /tmp/idcdb_backup.sql s3://aurora-global-db-backup-<ACCOUNT_ID>/migration/

# Aurora로 복원 (Beanstalk 또는 관리 인스턴스에서)
mysql -h <AURORA_ENDPOINT> -u admin -p'AdminPassword123!' globaldb < /tmp/idcdb_backup.sql
```

### 방법 2: AWS DMS (Database Migration Service)
1. DMS Replication Instance 생성
2. Source Endpoint: IDC MySQL
3. Target Endpoint: Aurora
4. Migration Task 생성 및 실행

### 방법 3: SELECT INTO OUTFILE S3 (Aurora 직접)
```sql
-- Aurora에서 실행
LOAD DATA FROM S3 's3://aurora-global-db-backup-<ACCOUNT_ID>/migration/data.csv'
INTO TABLE your_table
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n';
```

## Tokyo 리전 확장

Tokyo Secondary Cluster가 배포되어 있습니다:
```terraform
resource "aws_rds_cluster" "aurora_tokyo" {
  provider                  = aws.tokyo
  cluster_identifier        = "aurora-global-tokyo-cluster"
  engine                    = aws_rds_global_cluster.aurora_global.engine
  engine_version            = aws_rds_global_cluster.aurora_global.engine_version
  global_cluster_identifier = aws_rds_global_cluster.aurora_global.id
  # 1개 Reader 인스턴스 (db.r5.large)
}
```

**Tokyo Reader Endpoint (읽기 전용)**:
```
aurora-global-tokyo-cluster.cluster-ro-xxxxx.ap-northeast-1.rds.amazonaws.com:3306
```

## 접속 정보

### Writer Endpoint (읽기/쓰기)
```
aurora-global-seoul-cluster.cluster-xxxxx.ap-northeast-2.rds.amazonaws.com:3306
```

### Reader Endpoint (읽기 전용)
```
aurora-global-seoul-cluster.cluster-ro-xxxxx.ap-northeast-2.rds.amazonaws.com:3306
```

### 인증 정보
- **Username**: admin
- **Password**: AdminPassword123! (변경 권장)
- **Database**: globaldb

## 모니터링

- **CloudWatch Alarms**: CPU 80% 이상, 연결 800개 이상
- **Performance Insights**: 활성화됨
- **CloudWatch Logs**: audit, error, general, slowquery

## 비용

- **db.r5.large**: 약 $0.29/시간 × 3개 인스턴스 = $627/월
  - Seoul: Writer 1개 + Reader 1개
  - Tokyo: Reader 1개
- **Storage**: $0.10/GB-월 (증분)
- **I/O**: $0.20/백만 요청
- **백업**: 7일 무료, 이후 $0.021/GB-월

**비용 절감**:
- 이전(db.r6g.large × 5개): ~$1,036/월
- 현재(db.r5.large × 3개): ~$627/월
- 월 $409 절감 (약 40% 비용 감소)

## 보안

- ✅ 암호화된 스토리지
- ✅ VPC 내부 배치
- ✅ 보안 그룹으로 접근 제어
- ✅ IAM 역할 기반 S3 접근
- ⚠️ 마스터 비밀번호 변경 권장 (AWS Secrets Manager 사용)
