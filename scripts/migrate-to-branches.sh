#!/bin/bash

# =============================================================================
# Helm 브랜치별 분리 마이그레이션 스크립트
# =============================================================================

set -e

echo "🚀 Starting Helm branch-based migration..."

# 현재 브랜치 백업
CURRENT_BRANCH=$(git branch --show-current)
echo "📦 Current branch: $CURRENT_BRANCH"

# Step 1: 백업 브랜치 생성
echo "📦 Creating backup branch..."
git checkout -b "backup-before-migration-$(date +%Y%m%d-%H%M%S)"
git checkout $CURRENT_BRANCH

# Step 2: Main 브랜치 정리 (Source of Truth)
echo "🔧 Preparing main branch as Source of Truth..."

# base.yaml 내용을 임시 파일로 저장
cp helm/environments/base.yaml /tmp/base-values.yaml

# 각 서비스 차트의 values.yaml을 base.yaml 기반으로 업데이트
SERVICES="auth-service board-service chat-service frontend noti-service storage-service user-service video-service"

for service in $SERVICES; do
    echo "  📝 Updating $service values.yaml with base configuration..."
    
    # 기존 values.yaml 백업
    if [ -f "helm/charts/$service/values.yaml" ]; then
        cp "helm/charts/$service/values.yaml" "helm/charts/$service/values.yaml.backup"
    fi
    
    # base.yaml을 기본값으로 복사하고 서비스별 설정 추가
    cp /tmp/base-values.yaml "helm/charts/$service/values.yaml"
    
    # 기존 서비스별 설정이 있다면 병합 (수동 작업 필요)
    echo "    ⚠️  Manual merge required for $service specific configurations"
done

# wealist-infrastructure도 동일하게 처리
echo "  📝 Updating wealist-infrastructure values.yaml..."
if [ -f "helm/charts/wealist-infrastructure/values.yaml" ]; then
    cp "helm/charts/wealist-infrastructure/values.yaml" "helm/charts/wealist-infrastructure/values.yaml.backup"
fi
cp /tmp/base-values.yaml "helm/charts/wealist-infrastructure/values.yaml"

# Step 3: 중복 파일들 제거
echo "🧹 Cleaning up duplicate values files..."
find helm/charts -name "values-develop-registry-local.yaml" -delete
find helm/charts -name "values-*.yaml" ! -name "values.yaml" -delete

# Step 4: 환경별 브랜치 생성
echo "🌿 Creating environment branches..."

# Dev 브랜치
echo "  📝 Creating dev branch..."
git checkout -b dev
# dev.yaml 내용으로 각 서비스 values.yaml 업데이트
for service in $SERVICES wealist-infrastructure; do
    if [ -f "helm/environments/dev.yaml" ]; then
        echo "    🔄 Updating $service for dev environment..."
        # 여기서 dev.yaml의 내용을 각 서비스 values.yaml에 병합
        # (실제로는 yq나 다른 YAML 처리 도구 필요)
        echo "    ⚠️  Manual configuration needed for $service"
    fi
done

# Staging 브랜치
git checkout main
git checkout -b staging
echo "  📝 Creating staging branch..."
for service in $SERVICES wealist-infrastructure; do
    if [ -f "helm/environments/staging.yaml" ]; then
        echo "    🔄 Updating $service for staging environment..."
        echo "    ⚠️  Manual configuration needed for $service"
    fi
done

# Prod 브랜치
git checkout main
git checkout -b prod
echo "  📝 Creating prod branch..."
for service in $SERVICES wealist-infrastructure; do
    if [ -f "helm/environments/prod.yaml" ]; then
        echo "    🔄 Updating $service for prod environment..."
        echo "    ⚠️  Manual configuration needed for $service"
    fi
done

# Step 5: ArgoCD 앱 정의 업데이트
git checkout main
echo "🔄 Updating ArgoCD applications..."

# 환경별 ArgoCD 앱 생성 (예시)
cat > argocd/apps/auth-service-dev.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: auth-service-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/wealist-argo-helm
    targetRevision: dev
    path: helm/charts/auth-service
  destination:
    server: https://kubernetes.default.svc
    namespace: wealist-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "✅ Migration structure created!"
echo ""
echo "📋 Next steps:"
echo "1. Manually merge environment-specific configurations into each branch"
echo "2. Update ArgoCD applications to point to correct branches"
echo "3. Test deployments in each environment"
echo "4. Update Makefile for branch-based operations"
echo "5. Set up branch protection rules"
echo ""
echo "🔍 Check the migration-plan.md for detailed instructions"