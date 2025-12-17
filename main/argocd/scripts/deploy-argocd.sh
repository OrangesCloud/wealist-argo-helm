#!/bin/bash
set -e

echo "🚀 Starting ArgoCD deployment..."

# GitHub 저장소 정보
REPO_URL="https://github.com/OrangesCloud/wealist-argo-helm.git"

# 1. ArgoCD 설치
echo "📦 Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Sealed Secrets 설치
echo "🔐 Installing Sealed Secrets Controller..."
# Helm repo 추가 (이미 있어도 에러 없이 진행)
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets 2>/dev/null || true
helm repo update

# Sealed Secrets 설치 (이미 있으면 업그레이드)
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  -n kube-system \
  --set fullnameOverride=sealed-secrets \
  --wait --timeout=300s

# 3. ArgoCD 서버 준비 대기
echo "⏳ Waiting for ArgoCD server..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# 4. Sealed Secrets Controller 준비 대기
echo "⏳ Waiting for Sealed Secrets Controller..."
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets -n kube-system

# 5. 네임스페이스 생성
echo "📁 Creating application namespace..."
kubectl create namespace wealist-dev --dry-run=client -o yaml | kubectl apply -f -

# 6. CRD 확인
echo "🔍 Verifying Sealed Secrets installation..."
kubectl get crd sealedsecrets.bitnami.com || {
    echo "❌ SealedSecrets CRD not found. Installation may have failed."
    exit 1
}
echo "✅ SealedSecrets CRD is ready!"

# 7. SealedSecret 적용 (파일이 존재하는 경우)
echo "🔐 Applying SealedSecrets..."
SEALED_SECRET_FILES=(
    "sealed-secret-dev.yaml"
    "main/helm/charts/wealist-infrastructure/templates/sealed-secret-dev.yaml"
    "main/helm/environments/sealed-secret-dev.yaml"
)

SEALED_SECRET_APPLIED=false
for file in "${SEALED_SECRET_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "📝 Found SealedSecret file: $file"
        
        # 네임스페이스 확인 및 적용
        if kubectl apply -f "$file" 2>/dev/null; then
            echo "✅ Successfully applied SealedSecret: $file"
            SEALED_SECRET_APPLIED=true
            break
        else
            echo "⚠️  Failed to apply $file, trying with wealist-dev namespace..."
            if kubectl apply -f "$file" -n wealist-dev --force 2>/dev/null; then
                echo "✅ Applied SealedSecret to wealist-dev namespace: $file"
                SEALED_SECRET_APPLIED=true
                break
            fi
        fi
    fi
done

if [ "$SEALED_SECRET_APPLIED" = false ]; then
    echo "⚠️  No SealedSecret files found. You may need to create and apply them manually."
    echo "ℹ️  Expected files: sealed-secret-dev.yaml"
fi

# 8. SealedSecret이 Secret으로 변환되는지 확인
echo "⏳ Waiting for SealedSecret to create Secret..."
sleep 10

SECRET_CREATED=$(kubectl get secrets -n wealist-dev --no-headers 2>/dev/null | wc -l)
if [ "$SECRET_CREATED" -gt 0 ]; then
    echo "✅ Secrets created in wealist-dev namespace:"
    kubectl get secrets -n wealist-dev
else
    echo "⚠️  No secrets found in wealist-dev namespace yet."
fi

# 9. GitHub 저장소 인증 설정
echo "🔑 Setting up GitHub repository access..."
echo "ℹ️  You need a GitHub Personal Access Token with 'repo' permissions"
echo "ℹ️  Create one at: https://github.com/settings/tokens"
echo

read -p "Enter your GitHub username: " GITHUB_USERNAME

# Personal Access Token 입력 (화면에 표시되지 않음)
echo -n "Enter your GitHub Personal Access Token: "
read -s GITHUB_TOKEN
echo

# 10. 저장소 Secret 생성
echo "📝 Creating repository secret..."
kubectl create secret generic wealist-repo -n argocd \
  --from-literal=type=git \
  --from-literal=url=$REPO_URL \
  --from-literal=username=$GITHUB_USERNAME \
  --from-literal=password=$GITHUB_TOKEN \
  --dry-run=client -o yaml | kubectl apply -f -

# ArgoCD가 인식할 수 있도록 라벨 추가
kubectl label secret wealist-repo -n argocd \
  argocd.argoproj.io/secret-type=repository --overwrite

echo "✅ Repository access configured successfully!"

# 11. ArgoCD 서버가 완전히 준비될 때까지 추가 대기
echo "⏳ Waiting for ArgoCD to be fully ready..."
sleep 30

# 12. AppProject 생성 (파일이 존재하는 경우에만)
if [ -f "../apps/project.yaml" ]; then
    echo "🎯 Creating AppProject..."
    kubectl apply -f ../apps/project.yaml
else
    echo "⚠️  AppProject file not found at ../apps/project.yaml"
fi

# 13. Root Application 생성 (파일이 존재하는 경우에만)
if [ -f "../apps/root-app.yaml" ]; then
    echo "🌟 Creating Root Application..."
    kubectl apply -f ../apps/root-app.yaml
else
    echo "⚠️  Root Application file not found at ../apps/root-app.yaml"
fi

# 14. ArgoCD 초기 비밀번호 가져오기
echo "🔧 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Password not found")

# 15. 설치 상태 확인
echo "🔍 Checking installation status..."
echo "ArgoCD Pods:"
kubectl get pods -n argocd | grep -E "(Running|Ready)"
echo ""
echo "Sealed Secrets Pods:"
kubectl get pods -n kube-system | grep sealed
echo ""
echo "Available CRDs:"
kubectl get crd | grep sealed
echo ""
echo "SealedSecrets in wealist-dev:"
kubectl get sealedsecrets -n wealist-dev 2>/dev/null || echo "No SealedSecrets found"
echo ""
echo "Secrets in wealist-dev:"
kubectl get secrets -n wealist-dev 2>/dev/null || echo "No Secrets found"

# 16. 접속 정보 표시
echo ""
echo "✅ ArgoCD deployment completed!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 ArgoCD Access Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "URL:      https://localhost:8079"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "🔐 Sealed Secrets Information:"
echo "Controller: sealed-secrets (kube-system namespace)"
echo "Service:    sealed-secrets"
echo ""
echo "📋 Next steps:"
echo "1. Access ArgoCD UI at the URL above"
echo "2. Login with admin credentials"
echo "3. Check Applications tab to see your services"
echo "4. Verify SealedSecrets: kubectl get sealedsecrets -A"
echo "5. Sync applications if needed"
echo ""
if [ "$SEALED_SECRET_APPLIED" = false ]; then
echo "⚠️  Manual SealedSecret setup required:"
echo "   kubectl apply -f sealed-secret-dev.yaml -n wealist-dev"
echo ""
fi
echo "🔍 Useful commands:"
echo "kubectl get applications -n argocd"
echo "kubectl get pods -n wealist-dev"
echo "kubectl get sealedsecrets -n wealist-dev"
echo "kubectl get secrets -n wealist-dev"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 17. 포트포워딩 시작
echo "🌐 Starting port-forward (Ctrl+C to stop)..."
kubectl port-forward svc/argocd-server -n argocd 8079:443