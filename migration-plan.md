

# Helm 브랜치별 분리 마이그레이션 계획

## 현재 상황
- 단일 브랜치에서 helm/environments/*.yaml로 환경 관리
- 각 차트마다 values-develop-registry-local.yaml 등 중복 파일 존재
- Makefile에서 ENV 변수로 환경별 values 파일 선택

## 목표 구조
```
main (브랜치) - Source of Truth
├── k8s/helm/charts/
│   ├── auth-service/
│   │   ├── Chart.yaml
│   │   ├── templates/
│   │   └── values.yaml          # 기본값만 (base.yaml 내용 통합)
│   └── ...
├── k8s/argocd/apps/
│   ├── auth-service-dev.yaml    # dev 브랜치 참조
│   ├── auth-service-staging.yaml
│   └── auth-service-prod.yaml
└── makefiles/                   # 공통 빌드 로직

dev (브랜치)
└── k8s/helm/charts/
    ├── auth-service/
    │   └── values.yaml          # dev 전용 설정
    └── ...

staging (브랜치)
└── k8s/helm/charts/
    ├── auth-service/
    │   └── values.yaml          # staging 전용 설정
    └── ...

prod (브랜치)
└── k8s/helm/charts/
    ├── auth-service/
    │   └── values.yaml          # prod 전용 설정
    └── ...
```

## 마이그레이션 단계

### Phase 1: Main 브랜치 정리
1. helm/environments/base.yaml 내용을 각 차트의 values.yaml에 통합
2. 중복 values 파일들 제거 (values-develop-registry-local.yaml 등)
3. ArgoCD 앱 정의를 브랜치별로 분리

### Phase 2: 환경별 브랜치 생성
1. dev 브랜치 생성 및 dev.yaml 내용으로 values.yaml 설정
2. staging 브랜치 생성 및 staging.yaml 내용으로 values.yaml 설정  
3. prod 브랜치 생성 및 prod.yaml 내용으로 values.yaml 설정

### Phase 3: Makefile 및 스크립트 수정
1. 브랜치 기반 배포 로직으로 변경
2. 환경별 브랜치 체크아웃 자동화

### Phase 4: ArgoCD 설정 업데이트
1. 각 환경별 Application이 해당 브랜치를 참조하도록 수정
2. 자동 동기화 설정

## 장점
- 환경별 완전한 격리
- 코드 리뷰를 통한 프로덕션 배포 제어
- 환경별 독립적인 차트 버전 관리
- GitOps 워크플로우 강화

## 주의사항
- 공통 변경사항은 main → dev → staging → prod 순서로 머지
- 각 환경별 브랜치는 정기적으로 main과 동기화 필요
- 브랜치 보호 규칙 설정 (특히 prod)