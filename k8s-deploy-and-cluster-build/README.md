# 6章 Kubernetesのデプロイ・クラスタ構成

## 6.1 GKEのセットアップ

### 6.1.1 GCPプロジェクトの作成

gihyo-kube という名前でプロジェクトを作成
プロジェクトIDをメモる

## 6.1.2 gcloudのセットアップ

gcloudをインストールする
$ gcloud component update
$ gcloud auth login
$ gcloud config set project gihyo-kube-xxxxxx
$ gcloud config set compute/zone us-west1-a

なるべく金節約したいので us-west1-aを指定

## 6.1.3 k8sクラスタの作成

$ gcloud container clusters create gihyo --cluster-version=1.10.4-gke.2 \
    --machine-type=n1-standard-1 \
    --num-nodes=3

としたら、エラーが出た。どうもサポート対象外っぽい。
> ERROR: (gcloud.container.clusters.create) ResponseError: code=400, message=Master version "1.10.4-gke.2" is unsupported.

$ gcloud container get-server-config

して、対応バージョンを調べる。

この場合、validMasterVersions のところを見て、適当なやつを当てればいい。
僕はdefaultClusterVersion のところにあるバージョンを使った。

$ gcloud container clusters create gihyo --cluster-version=1.12.7-gke.10 \
    --machine-type=n1-standard-1 \
    --num-nodes=3

このコマンドもいいが、僕は貧乏(20万の洗濯機買ったり旅行行きまくったりした)なのでここの方法を使う。
https://blog.a-know.me/entry/2018/06/17/220222

### 1. 改善されたコマンド

$ gcloud container clusters create gihyo --cluster-version=1.12.7-gke.10 \
    --preemptible \
    --machine-type=f1-micro \
    --num-nodes=3 \
    --disk-size=10

続いてgcloudで作成したクラスタを制御できるようにするためにkubectlに認証情報をセットする

$ gcloud container clusters get-credentials gihyo

> Fetching cluster endpoint and auth data.
> kubeconfig entry generated for gihyo.

こう出れば成功。

$ kubectl get nodes

3つのnodeが出たら成功

### 2. クラスタの消し方

$ gcloud container clusters delete gihyo

一日の勉強終わりにはこれを実行し、無駄な金の発生を抑えることにする。

## 6.2 GKEにTODOアプリケーションを構築する

MySQL, API, Webアプリケーションの順でデプロイしていく。

## 6.3 Master Slave構成のMySQLをGKE上に構築する

### 6.3.1 PersistentVolumeとPersistentVolumeClaim

k8sではストレージを確保するためにPersistentVolumeとPersistentVolumeClaimというリソースが提供されている。
これらはクラスタが構築されてるプラットフォームに対応した永続ボリュームを作成するためのリソース。
PersistentVolumeはストレージの実体。GCPではGCEPersistentDiskがそれにあたる。
対してPersistentVolumeClaimはストレージを論理的に抽象化したリソース。PersistentVolumeに対して必要な容量を動的に確保できる
マニフェストファイルのイメージを以下に記す

```txt
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-example
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ssd
  resources:
    requests:
      storage: 4Gi
```

accessModes...Podからストレージへのマウントポリシーのこと
ReadWriteOnceであればどこか1つのノードからのR/Wマウントのみが許可される
storageClassNameは後述するStorageClassリソースの名前のこと
利用するストレージの種類を定義する

これはサンプルなので今回は使わない

### 6.3.2 StorageClass

StorageClassはPersistentVolumeが確保するストレージの種類を定義できるリソース

$ touch storage-class-ssd.yml

(詳しくはstorage-class-ssd.ymlを見ること)

ssdという名前のSSDに対応したストレージクラスを定義している。

$ kubectl apply -f storage-class-ssd.yml

### 6.3.3 StatefulSet

データストアのように継続的にデータを永続化するステートフルなアプリケーションの管理に向いたリソース
pod-0, pod-1, pod-n のような形で連番の識別子が振られる
識別子はPodが再作成されても保たれる

$ touch mysql-master.yml

(詳しくはmysql-masterを見ること)

$ kubctl apply -f mysql-master.yml

StatefulSetはステートフルなReplicaSetという位置づけ

#### Slaveの設定

$ touch mysql-slave.yml

(詳しくはmysql-slave.ymlを見ること)

$ kubectl apply -f mysql-slave.yml

#### 実行内容の確認

MasterのPodに`init-data.sh`で初期データを入れ、Slaveに反映されてるか確かめる

$ kubectl exec -it mysql-master-0 init-data.sh
> Error from server: error dialing backend: ssh: rejected: connect failed (Connection refused)

エラーが出た。sshで繋げない。しらべる。

というか、CrashLoopBackOffやErrorが大量に出てたくさん再起動してるのがよくなく見える。
なんとかする。

また、こんなエラーも…
> rpc error: code = 2 desc = containerd: container not found
> command terminated with exit code 126

とりあえずクラスタごと消す…

一旦コミット

2019/06/06

gihyodocker/tododbが変になってそうなので、自分でビルドしたイメージを使う

```sh
ghq get -p mimikun/tododb
C-g mimikun/tododb
docker image build -t mimikun/tododb:latest .
docker image push mimikun/tododb:latest
```

あとはyml内のgihyodocker/tododb をmimikun/tododbに置き換えるだけ…

解決した。

初期データ投入はこれで

$ kubectl exec -it mysql-master-0 /usr/local/bin/init-data.sh

## 6.4 TODO APIをGKE上に構築する

続いてTODO APIをGKE上に構築する。

$ touch todo-api.yml

(詳しくはtodo-api.ymlを見ること)

$ kubectl apply -f todo-api.yml

nginxコンテナはgihyodocker/nginx:latest, apiコンテナはgihyodocker/todoapi:latestを使用
ここではPodはNginxとAPIを一緒のPodにぶちこむ
Nginxでは環境変数でプロキシ先を指定するが、apiは同一Pod内に存在するのでlocalhost:8080で解決できる
MySQLのMasterはmysql-master, Slaveはmysql-slaveで名前解決できるようになっているので, 環境変数で接続先を指定する

Podの起動を確認:
$ kubectl get pod -l app=todoapi

## 6.5 TODO WebアプリケーションをGKE上に構築する

$ touch todo-web.yml

(詳しくはtodo-web.yml)を見ること

$ kubectl apply -f todo-web.yml

nginxコンテナはgihyodocker/nginx-nuxt:latest, apiコンテナはgihyodocker/todoweb:latestを使用
DeploymentではnginxとwebコンテナでPodを構成する
これもPodでは同梱すべき, nginxコンテナの環境変数BACKEND_HOSTは同じPod内のwebコンテナを指す。
ので、localhost:3000を、webコンテナの環境変数TODO_API_URLはtodoapiのService名をURLにしたもの。
assetsファイルをNginxに配置してレスポンスするためにk8sのVolumeを利用。
k8sのVolumeはDockerのそれと同じくデータを永続化するためのしくみ。
`emptyDir: {}`とすることでPod単位に割り当てられる仮想Volumeを作成している。
emptyDirには同一Pod内のそれぞれのコンテナから好きなパスでアクセスできる。
マウントするコンテナのパスはmountPathで指定する

仮想Volumeによってコンテナ間のディレクトリ共有が可能になった。
だが、仮想Volumeはまだからっぽ。
なので、webコンテナのassetsファイルをNginxコンテナにコピーしないといけない。
このようなケースではLifecycleイベントを使う。
多分ここ: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/
Lifecycleイベントはコンテナの開始時や終了時のタイミングで任意のコマンドを実行するための仕組み。
entrykitのprehookでも同じことができるが、Lifecycleイベントの場合はDockerfileに手を加えずにできるのでよい。
今回はportstartを使ってwebコンテナ開始時に仮想Volumeにassetsファイルをコピーする。
portstart.exec.commandで`cp -R /todoweb/.nuxt/dist /`を実行していて、`/dist`ディレクトリにassetsファイルがコピーされる。

webコンテナの`/dist`ディレクトリは仮想Volumeによってnginxコンテナにも共有されている。
nginxコンテナの`/var/www/_nuxt`ディレクトリにassetsが配置されることになる。

これでassetsファイルをnginxからレスポンス可になる。
このやりかたはPod内でコンテナ型ディレクトリ共有をするのに便利。
ServiceはのちほどIngressでインターネットから公開できるようにするため、NodePortというtypeを指定している。

サービスの状態を確認。

$ kubectl get service todoweb
> NAME      TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
> todoweb   NodePort   IPアドレス   <none>        80:32509/TCP   16m

今日はここまで。study-finish.shを実行。
