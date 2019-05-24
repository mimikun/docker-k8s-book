# 5章 Kubernetes入門
## 5.1 k8sとは
#コンテナオーケストレーションシステム。
#コンテナオーケストレーションとは…
#複数のノードをまたいで多くのコンテナ群を管理する手法のこと
## 5.2 ローカル環境でk8sを実行する
#kubectlを入れる。

#ダッシュボードのインストール
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.8.3/src/deploy/recommended/kubernetes-dashboard.yaml

#これを実行し、STATUS=Runningになってるか見る
kubectl get pod --namespace=kube-system -l k8s-app=kubernetes-dashboard

#ダッシュボードをwebで見るために、プロキシサーバを立てる
kubectl proxy

#ここにアクセス
#http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/overview?namespace=default

## 5.3 k8sの概念
ここまで
