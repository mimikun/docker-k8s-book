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
Fetching cluster endpoint and auth data.
kubeconfig entry generated for gihyo.

こう出れば成功。

$ kubectl get nodes

3つのnodeが出たら成功

### 2. クラスタの消し方

gcloud container clusters delete gihyo

一日の勉強終わりにはこれを実行し、無駄な金の発生を抑えることにする。
