#!/bin/bash
set -e

echo "🚀 Starting ArgoCD deployment..."

# 1. ArgoCD 설치
echo "📦 Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. ArgoCD 서버 준비 대기
echo "⏳ Waiting for ArgoCD server..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 3. 네임스페이스 생성
echo "📁 Creating application namespace..."
kubectl create namespace wealist-dev --dry-run=client -o yaml | kubectl apply -f -

# 4. AppProject 생성
echo "🎯 Creating AppProject..."
kubectl apply -f main/argocd/apps/project.yaml

# 5. Root Application 생성
echo "🌟 Creating Root Application..."
kubectl apply -f main/argocd/apps/root-app.yaml

# 6. 포트포워딩 시작
echo "🌐 Starting port-forward..."
echo "ArgoCD UI: https://localhost:8079"
echo "Username: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
kubectl port-forward svc/argocd-server -n argocd 8079:443