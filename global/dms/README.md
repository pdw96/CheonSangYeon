# AWS DMS - IDC MySQL to Aurora Migration

AWS Database Migration Service를 사용하여 IDC MySQL을 Aurora Global Database로 마이그레이션합니다.

## 마이그레이션 전략

### Full Load + CDC (Change Data Capture)
1. **Full Load**: IDC MySQL의 모든 기존 데이터를 Aurora로 복사
2. **CDC**: 실시간으로 변경사항을 지속적으로 동기화

### 장점
- **무중단 마이그레이션**: 소스 DB가 계속 운영되면서 마이그레이션
- **데이터 일관성**: CDC를 통해 실시간 동기화
- **검증 가능**: Full Load 후 데이터 검증 가능

## 아키텍처

```
IDC MySQL (10.0.2.x:3306)
    ↓
DMS Replication Instance (Seoul Private Subnet)
    ↓
Aurora Global DB Writer (20.0.x.x:3306)
```

## 배포 순서

### 1. 사전 준비 확인
```bash
# Aurora가 먼저 배포되어 있어야 함
cd global/aurora
terraform output

# IDC DB 인스턴스 확인
cd ../../Seoul
terraform output idc_db_instance_private_ip
```

### 2. DMS 배포
```bash
cd global/dms
terraform init
terraform plan
terraform apply
```

### 3. 마이그레이션 시작
```bash
# Task ARN 가져오기
TASK_ARN=$(terraform output -raw migration_task_arn)

# 마이그레이션 시작
aws dms start-replication-task \
  --replication-task-arn $TASK_ARN \
  --start-replication-task-type start-replication \
  --region ap-northeast-2
```

### 4. 모니터링

#### Console에서 확인
https://ap-northeast-2.console.aws.amazon.com/dms/v2/home?region=ap-northeast-2#tasks

#### CLI로 상태 확인
```bash
aws dms describe-replication-tasks \
  --filters Name=replication-task-arn,Values=$TASK_ARN \
  --query 'ReplicationTasks[0].[Status,ReplicationTaskStats]' \
  --region ap-northeast-2
```

#### CloudWatch Logs 확인
```bash
aws logs tail /aws/dms/tasks/idc-to-aurora-migration-task \
  --follow \
  --region ap-northeast-2
```

### 5. 테이블 통계 확인
```bash
aws dms describe-table-statistics \
  --replication-task-arn $TASK_ARN \
  --region ap-northeast-2
```

## 마이그레이션 단계

### Phase 1: Full Load (초기 데이터 복사)
- IDC MySQL의 모든 테이블과 데이터를 Aurora로 복사
- 기존 테이블이 있으면 DROP하고 재생성 (DROP_AND_CREATE)
- 예상 시간: 데이터 크기에 따라 다름

### Phase 2: CDC (변경 데이터 캡처)
- Full Load 완료 후 자동으로 시작
- IDC MySQL의 실시간 변경사항을 Aurora에 반영
- Binary log를 읽어서 INSERT/UPDATE/DELETE 동기화

### Phase 3: 전환 준비
1. **애플리케이션 읽기 전환**
   - Beanstalk 앱을 Aurora Reader Endpoint로 변경
   - IDC MySQL은 여전히 쓰기용으로 사용

2. **지연 시간 확인**
   ```bash
   aws dms describe-replication-tasks \
     --filters Name=replication-task-arn,Values=$TASK_ARN \
     --query 'ReplicationTasks[0].ReplicationTaskStats.LatencyToTarget'
   ```

3. **최종 전환** (지연이 0에 가까울 때)
   - IDC MySQL을 읽기 전용으로 전환
   - 애플리케이션을 Aurora Writer Endpoint로 변경
   - DMS Task 중지

## 데이터 검증

### Row Count 비교
```sql
-- IDC MySQL에서
SELECT TABLE_NAME, TABLE_ROWS 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'idcdb';

-- Aurora에서
SELECT TABLE_NAME, TABLE_ROWS 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'globaldb';
```

### Checksum 비교
```bash
# DMS Task에 validation 활성화 (추가 설정 필요)
aws dms describe-table-statistics \
  --replication-task-arn $TASK_ARN \
  --filters Name=validation-state,Values=Failed
```

## 트러블슈팅

### 1. Connection 실패
```bash
# Source Endpoint 테스트
aws dms test-connection \
  --replication-instance-arn <INSTANCE_ARN> \
  --endpoint-arn <SOURCE_ENDPOINT_ARN>

# Target Endpoint 테스트
aws dms test-connection \
  --replication-instance-arn <INSTANCE_ARN> \
  --endpoint-arn <TARGET_ENDPOINT_ARN>
```

### 2. 느린 마이그레이션
- Replication Instance 크기 증가: `dms.t3.large` 또는 `dms.c5.xlarge`
- `MaxFullLoadSubTasks` 증가 (현재 8)
- `CommitRate` 증가 (현재 10000)

### 3. CDC 지연
- Binary log 확인: IDC MySQL에서 `binlog_format = ROW` 설정 필요
- Network latency 확인
- Aurora Write IOPS 확인

## 비용

### DMS Replication Instance
- **dms.t3.medium**: $0.164/시간 = ~$118/월
- **Storage (50GB)**: $0.115/GB-월 = $5.75/월

### 데이터 전송
- IDC → Aurora (VPN 통해): 무료 (같은 리전)
- CDC 실행 중: 계속 과금

### 총 예상 비용
- 마이그레이션 기간(1주): ~$40
- 장기 CDC 유지(1개월): ~$124

## 마이그레이션 후 정리

```bash
# DMS Task 중지
aws dms stop-replication-task \
  --replication-task-arn $TASK_ARN

# DMS 리소스 삭제
cd global/dms
terraform destroy

# 또는 Task만 중지하고 인스턴스는 유지 (롤백 대비)
```

## 롤백 계획

1. **즉시 롤백**: 애플리케이션을 다시 IDC MySQL로 변경
2. **부분 롤백**: Aurora → IDC 역방향 DMS Task 생성 (별도 설정 필요)
3. **데이터 손실 방지**: CDC가 계속 실행 중이면 IDC MySQL이 최신 상태 유지
