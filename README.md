# truve-terraform

`truve` 서비스의 AWS 인프라를 Terraform으로 관리하는 저장소입니다.  
현재 구성은 `dev` 환경을 기준으로 작성되어 있으며, 인프라 레이어와 플랫폼 레이어를 분리해 운영합니다.

## 개요

이 프로젝트는 크게 두 단계로 나뉩니다.

1. `infra`
AWS 기반 인프라를 생성합니다. VPC, EKS, RDS, ECR, 운영용 `ops-ec2` 등이 여기에 포함됩니다.

2. `platform`
이미 생성된 EKS 클러스터에 접속해 Kubernetes/Helm 기반 애드온을 설치합니다. 예를 들어 `metrics-server`, `aws-load-balancer-controller`, `Karpenter`, `StorageClass`, `Tempo IAM` 연동이 여기에 포함됩니다.

두 레이어는 별도 Terraform state를 사용하며, `platform`은 `infra`의 remote state를 참조합니다.

## 디렉터리 구조

```text
.
├── envs
│   └── dev
│       ├── infra
│       │   ├── vpc.tf
│       │   ├── eks.tf
│       │   ├── rds.tf
│       │   ├── ecr.tf
│       │   └── ops-ec2.tf
│       └── platform
│           ├── addons.tf
│           ├── karpenter.tf
│           ├── storageclass.tf
│           └── tempo-iam.tf
├── modules
│   ├── ecr
│   ├── eks-managed
│   ├── ops-ec2
│   ├── rds
│   ├── storage-class
│   └── vpc
└── scripts
    ├── destroy
    └── ops-ec2
```

## 주요 리소스

### `infra`

- VPC
  - CIDR: `10.1.0.0/16`
  - Public / Private / Database subnet 분리
  - 단일 NAT Gateway 사용
- EKS
  - Cluster name: `truve-eks-dev`
  - Kubernetes version: `1.34`
  - Managed Node Group 분리 운영
    - `system`
    - `cicd`
    - `monitoring`
    - `messaging`
  - EBS CSI Driver 및 EKS Pod Identity 사용
- RDS
  - MySQL 8.0
  - Multi-AZ 활성화
- ECR
  - `truve-backend`
  - `truve-frontend`
- Ops EC2
  - SSM 기반 운영용 인스턴스
  - `kubectl`, `helm`, `terraform`, `aws cli` 설치

### `platform`

- `metrics-server`
- `aws-load-balancer-controller`
- `Karpenter`
  - SQS interruption queue
  - EventBridge rule
  - Controller / Node IAM Role
- 기본 `gp3` StorageClass
- Tempo용 S3 접근 IAM Role + Pod Identity Association

## Terraform State

두 레이어 모두 S3 backend를 사용합니다.

- `infra`: `s3://truve-dev-tfstate/dev/infra/terraform.tfstate`
- `platform`: `s3://truve-dev-tfstate/dev/platform/terraform.tfstate`

설정 파일:

- `envs/dev/infra/backend.tf`
- `envs/dev/platform/backend.tf`

## 사전 준비

다음 도구가 필요합니다.

- Terraform `>= 1.6.0`
- AWS CLI
- kubectl
- Helm

AWS 인증은 적절한 IAM 권한을 가진 계정 또는 역할로 설정되어 있어야 합니다.

현재 코드에는 `profile` 설정이 대부분 주석 처리되어 있으므로, 기본 AWS credential chain을 사용하거나 환경 변수로 인증 정보를 주입하는 방식이 전제됩니다.

예시:

```bash
export AWS_REGION=ap-northeast-2
export AWS_PROFILE=truve-admin
```

## 배포 순서

### 1. infra 적용

```bash
cd envs/dev/infra
terraform init
terraform plan
terraform apply
```

이 단계에서 VPC, EKS, RDS, ECR, ops-ec2가 생성됩니다.

### 2. platform 적용

```bash
cd envs/dev/platform
terraform init
terraform plan
terraform apply
```

이 단계에서는 `infra`의 state를 읽어 EKS에 연결한 뒤, 클러스터 애드온과 IAM 연동 리소스를 생성합니다.

## 운영 스크립트

### Ops EC2 접속

SSM으로 운영용 EC2에 접속합니다.

```bash
./scripts/ops-ec2/connect-ops.sh
```

다른 이름의 인스턴스를 지정할 수도 있습니다.

```bash
./scripts/ops-ec2/connect-ops.sh ops-ec2
```

### Destroy 스크립트

클러스터 삭제는 일반 `terraform destroy`만으로 끝나지 않을 수 있어, 정리 절차를 단계별 스크립트로 제공합니다.

로컬 기준 전체 흐름 실행:

```bash
./scripts/destroy/run-from-local.sh
```

주요 흐름:

1. AWS 자격 증명 및 Terraform 환경 확인
2. EKS 관련 리소스 정리
3. ops-ec2 삭제
4. 최종 비용 리소스 검증

## 모듈 설명

- `modules/vpc`
  - `terraform-aws-modules/vpc/aws` 래퍼
  - EKS/Karpenter용 subnet tag 포함
- `modules/eks-managed`
  - `terraform-aws-modules/eks/aws` 래퍼
  - Pod Identity, EBS CSI Driver, access entry 설정 포함
- `modules/rds`
  - MySQL RDS 및 접근 보안 그룹 구성
- `modules/ecr`
  - 서비스별 ECR 리포지토리 생성
- `modules/ops-ec2`
  - 운영용 EC2, IAM Role, Instance Profile, SSM 접속 환경 구성
- `modules/storage-class`
  - Kubernetes StorageClass 리소스 생성

## 운영 시 주의사항

- `platform`은 `infra`가 먼저 생성되어 있어야 정상 동작합니다.
- 일부 값은 현재 `dev` 환경에 하드코딩되어 있습니다.
  - 예: 클러스터명, Route53 zone ID, S3 bucket 이름
- `envs/dev/infra/rds.tf`에는 RDS 계정 정보가 코드에 직접 선언되어 있습니다.
  - 운영 환경에서는 Secrets Manager 또는 별도 비밀 관리 방식으로 전환하는 것을 권장합니다.
- `modules/ops-ec2`는 현재 `AdministratorAccess`를 사용합니다.
  - 초기 구축에는 편하지만, 장기적으로는 최소 권한 정책으로 축소하는 것이 좋습니다.
- `karpenter.tf`의 IAM 권한 역시 초안 단계로 넓게 열려 있습니다.
  - 실운영 전 최소 권한 검토가 필요합니다.

## 참고

- AWS region: `ap-northeast-2`
- Project tag: `truve`
- Environment tag: `dev`

## 향후 개선 아이디어

- `dev` 외 환경(`stage`, `prod`) 구조 확장
- 민감 정보 외부화
- CI/CD 기반 Terraform plan/apply 파이프라인 추가
- README에 실제 운영 아키텍처 다이어그램 추가
