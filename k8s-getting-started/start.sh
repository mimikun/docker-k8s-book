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
#使いそうな概念から
#Node: k8sクラスタ内で実行するコンテナを配置するためのサーバ
#Namespace: k8sクラスタ内で作る仮想的なクラスタ
#Pod: コンテナ集合体の単位で、コンテナを実行する方法を定義する
#Service: Podの集合にアクセスするための経路を定義する
#Ingress: Serviceをk8sクラスタの外に公開する

## 5.4 k8sクラスタとNode
#Node...クラスタが持つリソースで最も大きな概念。
#k8sクラスタは、masterとNode群によって構成される

#このコマンドで、クラスタに参加しているNodeの一覧を取得できる
kubectl get nodes

## 5.5 Namespace
#このコマンドでクラスタが持つNamespaceの一覧を取得できる
kubectl get namespace

## 5.6 Pod
#k8sをDockerと組み合わせる場合、Podが持つのはDockerコンテナ単体あるいはDockerコンテナの集合
#同一Pod内のコンテナはすべて同一のNodeに配置される

### 5.6.1 Podを作成してデプロイする
simple-pod.ymlをつかう ここまで
