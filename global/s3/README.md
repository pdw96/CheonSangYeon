# Global S3 Bucket for Aurora Global Database

이 모듈은 Aurora Global Database와 연동할 S3 버킷을 생성합니다.

## 기능

### Primary Bucket (Seoul - ap-northeast-2)
- **버킷명**: `aurora-global-db-backup-{account-id}`
- **버전 관리**: 활성화
- **암호화**: AES256 서버 측 암호화
- **퍼블릭 액세스**: 전면 차단
- **라이프사이클 정책**:
  - 30일 후: Standard-IA로 전환
  - 90일 후: Glacier Instant Retrieval로 전환
  - 180일 후: Deep Archive로 전환
  - 이전 버전은 90일 후 삭제

### Replica Bucket (Tokyo - ap-northeast-1)
- **버킷명**: `aurora-global-db-backup-replica-{account-id}`
- **교차 리전 복제**: Seoul → Tokyo 자동 복제
- **재해 복구**: 리전 장애 시 Tokyo에서 복구 가능

## 사용법

```bash
cd global/s3
terraform init
terraform plan
terraform apply
```

## Aurora Global Database 연동

생성된 S3 버킷을 Aurora에서 사용하려면:

1. Aurora 클러스터에 S3 액세스 권한 부여
2. `aws_s3.query_export_to_s3()` 함수로 데이터 내보내기
3. `LOAD DATA FROM S3` 명령으로 데이터 가져오기

## 보안

- 버전 관리로 실수로 인한 삭제 방지
- 암호화로 데이터 보안 강화
- 퍼블릭 액세스 차단으로 외부 노출 방지
- IAM 역할 기반 액세스 제어

## 비용 최적화

- 라이프사이클 정책으로 오래된 백업을 저렴한 스토리지로 자동 이동
- 이전 버전 자동 삭제로 스토리지 비용 절감
