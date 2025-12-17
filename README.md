# wealist-argo-helm

** envirment/secret 환경변수 값 넣어야 됨 **

chars -개별적인 service 부분

environments - 개별적인 부분 local, dev, stageing chart는 절대 바꾸지 않고 3 브렌치에서 공통적으로 가져가는 부분


### helm 수행전에 실행되어야 하는 것
- service단에서의 이미지만 빌드 수행 - localhost:5001/service:latest 를... 생성
## 로컬 환경 방법
- main/installShell/00,01,02, sh 실행 
```bash
curl -s http://localhost:5001/v2/_catalog | jq
```
수행해서 레지스터에 이미지 올라간걸 확인 가능

- make helm-install-all ENV=local-kind (로컬 환경)으로 수행 하면 된다.
- argocd/scripts/deploy-argocd.sh 수행할것
- 끝
## dev 환경 방법