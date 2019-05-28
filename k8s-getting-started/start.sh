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
#simple-pod.ymlをつかう
#kind はk8sのリソースを指定する属性 ここではPodを指定
#kindの値次第でspec配下のスキーマが変わる

#applyを使ってローカルk8sクラスタに反映する
kubectl apply -f simple-pod.yml

### 5.6.2 Podを操作する
#Podの状態を一覧取得
kubectl get pod

#kubectl execでコンテナ内に入る
kubectl exec -it simple-echo sh -c nginx
#Podの中に複数コンテナがある時は-cで指定

#kubectl logs でPodコンテナ内の標準出力を取得
kubectl logs -f simple-echo -c echo

#Podを削除
kubectl delete pod simple-echo

#マニフェストファイル(.yml)ベースで削除も可
kubectl delete -f simple-echo.yml

## 5.7 ReplicaSet
#同じ仕様のPodを複数生成、管理するためのリソース
#ReplicaSetはWebアプリ向け

## 5.8 Deployment
