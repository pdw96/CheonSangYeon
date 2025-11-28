# ECR → Azure App Service 배포 가이드

## 개요
AWS Elastic Beanstalk과 Azure App Service에서 동일한 ECR 이미지를 사용하여 멀티 클라우드 DR 환경을 구축합니다.

## 아키텍처

```
GitHub Repository
    ↓ (Git Push)
GitHub Actions
    ↓ (Build & Push)
AWS ECR (ap-northeast-2)
    ├─→ Elastic Beanstalk (AWS Seoul)
    └─→ App Service (Azure Korea Central)
```

## 1단계: ECR Repository 및 이미지 확인

### ECR Repository 목록 확인
```bash
aws ecr describe-repositories --region ap-northeast-2
```

### 기존 이미지 확인
```bash
# Repository 이름을 확인한 후
aws ecr list-images --repository-name <repository-name> --region ap-northeast-2

# 이미지 상세 정보
aws ecr describe-images --repository-name <repository-name> --region ap-northeast-2
```

## 2단계: ECR 인증 토큰 생성

### 토큰 생성 (12시간 유효)
```bash
aws ecr get-login-password --region ap-northeast-2
```

**중요**: 
- 이 토큰은 12시간마다 만료됩니다
- CI/CD 파이프라인에서 자동으로 갱신하도록 설정해야 합니다

### 토큰 복사
생성된 긴 문자열을 복사하여 `Azure/terraform.tfvars`의 `ecr_password`에 설정합니다.

## 3단계: terraform.tfvars 업데이트

`Azure/terraform.tfvars` 파일을 편집:

```terraform
# ===== ECR Settings (for Container Deployment) =====
ecr_registry_url = "299145660695.dkr.ecr.ap-northeast-2.amazonaws.com"  # 실제 Account ID로 변경
ecr_image_name   = "my-app:latest"  # 실제 Repository 이름과 태그로 변경
ecr_username     = "AWS"
ecr_password     = "eyJwYXlsb2FkIjoiQ..."  # 2단계에서 생성한 토큰
```

**보안 주의사항**:
- `ecr_password`는 Terraform state 파일에 암호화되어 저장됩니다
- State 파일을 Git에 커밋하지 마세요
- 프로덕션 환경에서는 Azure Key Vault 사용을 권장합니다

## 4단계: Azure App Service 배포

### Terraform 초기화 및 검증
```bash
cd Azure
terraform init
terraform validate
terraform plan
```

### 배포 실행
```bash
terraform apply -auto-approve
```

**예상 소요 시간**: 5-10분

**배포 과정**:
1. App Service가 ECR에 연결
2. 컨테이너 이미지 Pull
3. 컨테이너 시작 및 Health Check
4. 트래픽 라우팅

## 5단계: 배포 검증

### App Service URL 접근
```bash
# App Service URL 확인
terraform output app_service_url

# 브라우저에서 접근
https://webapp-dr-multicloud.azurewebsites.net
```

### Health Check 확인
```bash
curl https://webapp-dr-multicloud.azurewebsites.net/health
```

### 컨테이너 로그 확인
```bash
az webapp log tail \
  --name webapp-dr-multicloud \
  --resource-group rg-dr-multicloud
```

### Azure Portal에서 확인
1. Azure Portal > App Services > webapp-dr-multicloud
2. "Deployment Center" 메뉴에서 컨테이너 상태 확인
3. "Log stream" 메뉴에서 실시간 로그 확인

## 6단계: GitHub Actions CI/CD 설정

### 워크플로우 파일 생성
`.github/workflows/deploy-multicloud.yml`:

```yaml
name: Deploy to Multi-Cloud

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY: my-app  # 실제 Repository 이름으로 변경

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build, tag, and push image to Amazon ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
      
      - name: Update Azure App Service (Optional)
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          # ECR 토큰 생성
          ECR_PASSWORD=$(aws ecr get-login-password --region ${{ env.AWS_REGION }})
          
          # Azure App Service 설정 업데이트
          az webapp config container set \
            --name webapp-dr-multicloud \
            --resource-group rg-dr-multicloud \
            --docker-custom-image-name $ECR_REGISTRY/$ECR_REPOSITORY:latest \
            --docker-registry-server-url https://$ECR_REGISTRY \
            --docker-registry-server-user AWS \
            --docker-registry-server-password $ECR_PASSWORD
          
          # App Service 재시작
          az webapp restart \
            --name webapp-dr-multicloud \
            --resource-group rg-dr-multicloud
```

### GitHub Secrets 설정

GitHub Repository > Settings > Secrets and variables > Actions:

- `AWS_ACCESS_KEY_ID`: AWS Access Key
- `AWS_SECRET_ACCESS_KEY`: AWS Secret Access Key

## 7단계: ECR 토큰 자동 갱신 (선택사항)

ECR 토큰은 12시간마다 만료되므로, 자동 갱신 메커니즘이 필요합니다.

### 방법 1: GitHub Actions (권장)
위의 워크플로우에서 배포 시마다 새로운 토큰 생성

### 방법 2: AWS Lambda + EventBridge
```python
# Lambda 함수: ECR 토큰을 Azure App Service에 업데이트
import boto3
import json
import os

def lambda_handler(event, context):
    ecr = boto3.client('ecr', region_name='ap-northeast-2')
    
    # ECR 토큰 생성
    response = ecr.get_authorization_token()
    token = response['authorizationData'][0]['authorizationToken']
    
    # Azure CLI를 사용하여 App Service 업데이트
    # (Lambda에 Azure CLI 설치 필요)
    os.system(f"""
        az webapp config container set \
          --name webapp-dr-multicloud \
          --resource-group rg-dr-multicloud \
          --docker-registry-server-password {token}
    """)
    
    return {'statusCode': 200, 'body': 'Token updated'}
```

**EventBridge Rule**: 매 10시간마다 Lambda 실행

## 트러블슈팅

### 문제 1: 컨테이너 시작 실패
```bash
# 로그 확인
az webapp log tail --name webapp-dr-multicloud --resource-group rg-dr-multicloud

# 일반적인 원인:
# - ECR 인증 실패 → 토큰 재생성 및 업데이트
# - 이미지가 존재하지 않음 → ECR에서 이미지 확인
# - Health Check 실패 → 애플리케이션 /health 엔드포인트 확인
```

### 문제 2: ECR 인증 실패
```bash
# 토큰 재생성
NEW_TOKEN=$(aws ecr get-login-password --region ap-northeast-2)

# App Service 업데이트
az webapp config container set \
  --name webapp-dr-multicloud \
  --resource-group rg-dr-multicloud \
  --docker-registry-server-password $NEW_TOKEN

# 재시작
az webapp restart --name webapp-dr-multicloud --resource-group rg-dr-multicloud
```

### 문제 3: 데이터베이스 연결 실패
```bash
# App Service에서 Azure MySQL 연결 테스트
az webapp ssh --name webapp-dr-multicloud --resource-group rg-dr-multicloud

# 컨테이너 내부에서
mysql -h mysql-dr-multicloud.mysql.database.azure.com -u sqladmin -p webapp_db

# 연결 문자열 확인
az webapp config appsettings list \
  --name webapp-dr-multicloud \
  --resource-group rg-dr-multicloud \
  | grep DB_
```

## 모니터링

### Application Insights 연동
Azure Portal > App Service > Application Insights에서 활성화

### 주요 메트릭
- **Container Startup Time**: 컨테이너 시작 시간
- **HTTP Response Time**: 응답 시간
- **HTTP Error Rate**: 오류 비율
- **Memory Usage**: 메모리 사용률
- **CPU Usage**: CPU 사용률

### 알림 설정
```bash
# 컨테이너 재시작 알림
az monitor metrics alert create \
  --name "Container Restart Alert" \
  --resource-group rg-dr-multicloud \
  --scopes /subscriptions/.../webapp-dr-multicloud \
  --condition "count Restarts > 3" \
  --window-size 5m \
  --action-group <action-group-id>
```

## 비용 최적화

### ECR → Azure 데이터 전송 비용
- **AWS Seoul → Azure Korea Central**: 리전 간 데이터 전송 비용 발생
- **최적화 방법**:
  1. 이미지 크기 최소화 (멀티 스테이지 빌드)
  2. Azure Container Registry 복제 고려 (높은 빈도 배포 시)
  3. 캐싱 전략 활용

### App Service 비용
- **현재 SKU**: B1 (Basic) - 약 $13/월
- **업그레이드 옵션**: P1v3 (Premium) - 자동 스케일링, 슬롯 배포

## 다음 단계

1. **로드 밸런싱**: Azure Front Door로 AWS-Azure 간 트래픽 분산
2. **자동 페일오버**: Health Check 기반 자동 DR 전환
3. **데이터 동기화**: DMS Continuous Replication 활성화
4. **보안 강화**: Azure Key Vault로 ECR 자격 증명 관리
5. **모니터링 강화**: Azure Monitor + AWS CloudWatch 통합

## 참고 자료

- [Azure App Service 컨테이너 배포](https://learn.microsoft.com/azure/app-service/quickstart-custom-container)
- [AWS ECR 인증](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html)
- [GitHub Actions for Azure](https://github.com/Azure/actions)
