# wealist-argo-helm

## 로컬 환경 방법
- service단에서의 이미지만 빌드 수행 - localhost:5001/service:latest 를... 생성
- dev/01.sh ~ 02, 수행 
```bash
curl -s http://localhost:5001/v2/_catalog | jq
```
수행해서 레지스터에 이미지 올라간걸 확인 가능

- make helm-install-all ENV=local-kind (로컬 환경)으로 수행 하면 된다.

## dev 환경 방법