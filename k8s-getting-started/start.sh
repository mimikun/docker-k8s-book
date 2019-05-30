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
#ReplicaSetより上位のリソース
#アプリケーションデプロイの基本単位となるリソース
#ReplicaSetを管理・操作するために提供されているリソース
#Deploymentは、ReplicaSetの世代管理(リビジョン付け)を可能にする。
#kubectlのコマンドを記録するために、--recordオプションをつけて実行。
kubectl apply -f simple-deployment.yml --record
# こんな感じ
# NAME                        READY     STATUS              RESTARTS   AGE
# pod/echo-8556ddbfb9-pw7zq   0/2       ContainerCreating   0          29s
# pod/echo-mj2r8              2/2       Running             0          25m
# pod/echo-q89vh              2/2       Running             0          25m
# pod/echo-wlbpb              2/2       Running             0          25m

# NAME                                    DESIRED   CURRENT   READY     AGE
# replicaset.extensions/echo              3         3         3         25m
# replicaset.extensions/echo-8556ddbfb9   1         1         0         29s

# NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
# deployment.extensions/echo   3         4         1            3           32s

#Deploymentのリビジョンはこれで確認。
kubectl rollout history deployment echo
# こんな感じ
# deployments "echo"
# REVISION  CHANGE-CAUSE
# 0         <none>
# 1         kubectl apply --filename=simple-deployment.yml --record=true

### ReplicaSetライフサイクル
#k8sではDeploymentを一つの単位としてアプリケーションをデプロイしていく
#実運用ではReplicaSetはほとんど使わない。Deploymentのマニフェストファイルを扱う運用にすることがほとんど
#### Pod数のみを更新しても、新しいReplicaSetは生まれない。
#replicasを4つに増やし以下を実行
kubectl apply -f simple-deployment.yml --record
#新しくReplicaSetが生成されていればリビジョン番号が表示されるはずだが、表示されていない
#つまりreplicasの変更ではReplicaSetの入れ替えは発生しない
# ➜  k8s-getting-started git:(master) ✗ kubectl rollout history deployment echo
# deployments "echo"
# REVISION  CHANGE-CAUSE
# 0         <none>
# 1         kubectl apply --filename=simple-deployment.yml --record=true

#### コンテナ定義を変更
#コンテナのイメージを変更した場合
#このように新しいPodが生成され、古いのは消えていく
# ➜  k8s-getting-started git:(master) ✗ kubectl get pod
# NAME                    READY     STATUS              RESTARTS   AGE
# echo-7d9fb9c79f-thc72   0/2       ContainerCreating   0          2s
# echo-8556ddbfb9-ngdnz   2/2       Running             0          30m
# echo-8556ddbfb9-pw7zq   2/2       Running             0          31m
# echo-8556ddbfb9-tkxr9   2/2       Terminating         0          3m
# echo-8556ddbfb9-vmbhq   2/2       Running             0          31m

#この状態でリビジョンを確認すると、REVISION=2が作成されている
# deployments "echo"
# REVISION  CHANGE-CAUSE
# 0         <none>
# 1         kubectl apply --filename=simple-deployment.yml --record=true
# 2         kubectl apply --filename=simple-deployment.yml --record=true

#### 5.8.2 ロールバックを実行する
#Deploymentのリビジョンが記録されているため、特定のリビジョンの内容を確認できる
kubectl rollout history deployment echo --revision=1
# deployments "echo" with revision #1
# Pod Template:
#   Labels:	app=echo
# 	pod-template-hash=4112886965
#   Annotations:	kubernetes.io/change-cause=kubectl apply --filename=simple-deployment.yml --record=true
#   Containers:
#    nginx:
#     Image:	gihyodocker/nginx:latest
#     Port:	80/TCP
#     Host Port:	0/TCP
#     Environment:
#       BACKEND_HOST:	localhost:8080
#     Mounts:	<none>
#    echo:
#     Image:	gihyodocker/echo:latest
#     Port:	8080/TCP
#     Host Port:	0/TCP
#     Environment:	<none>
#     Mounts:	<none>
#   Volumes:	<none>

#undoを実行すれば直前の操作のリビジョンにロールバックできる
kubectl rollout undo deployment echo

#おわり、最後に全部消して掃除
kubectl delete -f simple-deployment.yml

## 5.9 Service
#k8sクラスタ内において、Podの集合に対する経路やサービスディスカバリを提供するためのリソース
#applyする
kubectl apply -f simple-replicaset-with-label.yml

#get podして、labelにspring, summerとついたpodがそれぞれ1つ, ２つあるか見る
kubectl get pod -l app=echo -l release=spring
# NAME                READY     STATUS    RESTARTS   AGE
# echo-spring-sfx2c   2/2       Running   0          46s
kubectl get pod -l app=echo -l release=summer
# NAME                READY     STATUS    RESTARTS   AGE
# echo-summer-5kmk5   2/2       Running   0          2m
# echo-summer-qm245   2/2       Running   0          36s

#release=summerを持つPodだけにアクセスできるようなServiceを作成する
#Serviceをapplyする
kubectl apply -f simple-service.yml

#kubectl get service echo でServiceを確認
# NAME      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# echo      ClusterIP   10.98.184.151   <none>        80/TCP    30s

#実際にrelease=summerを持つコンテナだけにトラフィックが流れるか確認する
#Serviceはk8sクラスタ内からしかアクセスできないので、デバッグ用コンテナをデプロイして、そこからいろいろする
kubectl run -i --rm --tty debug --image=gihyodocker/fundamental:0.1.0 --restart=Never -- bash -il

#いくつかのPodのログを確認し、received request がsummerのラベル付きPodにしか出てないことを確認する
kubectl get pods
# NAME                READY     STATUS    RESTARTS   AGE
# echo-spring-sfx2c   2/2       Running   0          16m
# echo-summer-5kmk5   2/2       Running   0          16m
# echo-summer-qm245   2/2       Running   0          14m
kubectl logs -f echo-spring-sfx2c -c echo
# 2019/05/30 12:18:32 start server
kubectl logs -f echo-summer-5kmk5 -c echo
# 2019/05/30 12:18:30 start server
# 2019/05/30 12:32:13 received request
kubectl logs -f echo-summer-qm245 -c echo
# 2019/05/30 12:20:06 start server
# 2019/05/30 12:32:04 received request
# 2019/05/30 12:32:06 received request
# 2019/05/30 12:32:07 received request

### 5.9.1 ClusterIP Service
#デフォルトのServiceはこれ
#k8sクラスタ上の内部IPアドレスにServiceを公開できる
#あるPodから別のPod群へのアクセスはここ介して行うことが可能
#外からは無理

### 5.9.2 NodePort Service
#クラスタ外からアクセスできるService

kubectl apply -f simple-nodeport-service.yml
kubectl get service echo
# NAME      TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# echo      NodePort   10.98.184.151   <none>        80:30378/TCP   16m
curl http://127.0.0.1:30378
# Hello Docker!!

### 5.9.3 LoadBalancer Service
#ローカル環境では利用できない
#クラウド環境(GCP...CLB, AWS...ELB)で使うやつ

### 5.9.4 ExternalName Service
#selectorもport定義も持たない
#k8sクラスタ内から外部のホストを解決するためのエイリアスを提供
#simple-externalname-service.ymlを作成すると, gihyo.jp をgihyo で名前解決できるようになる
