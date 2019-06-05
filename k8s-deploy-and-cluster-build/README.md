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
