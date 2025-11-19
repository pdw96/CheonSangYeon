# Code Review

## 요약
- Terraform 상태 파일과 민감 정보(자격 증명, 데이터베이스 초기화 스크립트 등)가 저장소에 그대로 커밋되어 있어 보안 및 운영 위험이 큽니다.
- IDC 모듈 전반에서 네트워크 경계가 제대로 분리되지 않아, "VPN 전용" 구성이더라도 DB/CGW 인스턴스가 인터넷에 직접 노출될 수 있습니다.
- 글로벌 Aurora 구성은 다른 팀에서 재사용하거나 자동화를 이식하기 어렵도록 특정 리소스 ID와 잘못된 데이터 소스 필터에 의존하고 있습니다.

## 상세 피드백

### 1. Git에 커밋된 Terraform 상태 파일
여러 디렉터리에 `terraform.tfstate`와 `tfplan` 파일이 저장되어 있습니다. 상태 파일에는 리소스 ID뿐 아니라 IAM 역할 ARN, VPN 터널 IP 등 민감 정보가 포함되므로, Git에 커밋되면 계정 탈취 및 인프라 스캐폴딩이 노출될 수 있습니다. `.gitignore`에 추가하고 원격 백엔드(S3+DynamoDB 등)만 사용하도록 정리하는 것을 권장합니다.

### 2. 데이터베이스 자격 증명/초기화 스크립트가 하드코딩됨
- `global/aurora/main.tf`는 `master_username`/`master_password`를 평문으로 선언해 비밀 관리가 불가능하고, 코드 열람만으로 운영 DB 암호가 노출됩니다.
- `Tokyo/scripts/db-setup.sh`는 root 암호(`Password123!`)와 응용계정(`idcuser`) 자격 증명을 그대로 user-data에 넣어 부팅 로그 및 메타데이터 서비스에 평문으로 남습니다. 또한 `bind-address = 0.0.0.0`으로 전체 인터넷에서 접속을 허용합니다.
AWS Secrets Manager/SSM Parameter Store와 같은 비밀 저장소를 사용하고, 초기화 스크립트에는 토큰만 주입하도록 바꿔야 합니다. DB 접근은 내부 네트워크 또는 bastion으로 제한하세요.

### 3. IDC 보안 그룹이 0.0.0.0/0에 전면 개방됨
`Seoul/modules/idc`와 `Tokyo/modules/idc`의 SG는 SSH(22/tcp), MySQL(3306/tcp), ICMP를 모두 `0.0.0.0/0`에 허용하고 있습니다. 이는 VPN 전용이라는 아키텍처 목표와 상충하며, 인터넷에서 곧바로 DB에 접속할 수 있게 만듭니다. 최소한 사설 CIDR/VPN 터널 IP로 제한하고, 운영 접근은 Session Manager/Bastion으로 대체해야 합니다.

### 4. 서울 IDC DB가 공용 서브넷/IGW에 위치
서울 IDC 모듈은 CGW와 DB가 동일한 공용 서브넷을 사용하며, 기본 라우트가 인터넷 게이트웨이(0.0.0.0/0 → IGW)로 설정되어 있습니다. 동시에 원격 IDC/VPC CIDR(20/16, 30/16, 40/16)을 CGW ENI로 정적 라우팅해 단일 EC2 인스턴스를 라우터·방화벽으로 삼고 있습니다. 이는 VPN 인스턴스 하나가 장애나 침해를 당하면 DB까지 곧바로 노출되는 구조입니다. 최소 요구 사항은 (1) DB를 프라이빗 서브넷으로 분리, (2) 기본 라우트를 NAT/방화벽 어플라이언스로 분리, (3) 네트워크 ACL 또는 AWS Network Firewall 등으로 양방향 트래픽을 제어하는 것입니다.

### 5. Aurora 서브넷 조회 로직이 항상 하드코딩 ID로 폴백
`global/aurora/main.tf`의 `data "aws_subnets"`는 `tag:Name` 필터에 와일드카드(`seoul-beanstalk-subnet-*`)를 넣고 있는데, AWS API는 와일드카드를 지원하지 않으므로 항상 빈 목록을 반환합니다. 결과적으로 `locals.seoul_subnet_ids`는 하드코딩된 서브넷 ID 두 개에 의존하게 되어, 다른 계정/환경에서는 바로 실패하거나 엉뚱한 서브넷을 참조하게 됩니다. 태그 셀렉터를 여러 `filter` 블록으로 나누거나, `for_each`로 조회 후 `starts_with` 조건으로 필터링하는 방식으로 수정해야 합니다.
