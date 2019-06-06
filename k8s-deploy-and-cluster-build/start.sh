#!/bin/bash

# クラスタの作成
gcloud container clusters create gihyo --cluster-version=1.12.7-gke.10 \
    --machine-type=n1-standard-1 \
    --num-nodes=3 \
    --disk-size=10

sleep 20
# kubectlに認証情報をセットする
gcloud container clusters get-credentials gihyo

# sleep 15
# クラスタの削除
# gcloud container clusters delete gihyo

sleep 20
# StorageClassの作成
kubectl apply -f storage-class-ssd.yml

sleep 20
# mysql-masterの反映
kubectl apply -f mysql-master.yml

sleep 20
# mysql-slaveの反映
kubectl apply -f mysql-slave.yml

sleep 20
# master Podに初期データ投入
kubectl exec -it mysql-master-0 /usr/local/bin/init-data.sh

# slaveにデータが入っているか確認
# kubectl exec -it mysql-slave-0 bash
# root# mysql -u root -pgihyo tododb
# mysql> SHOW TABLES;

sleep 20
# TODO APIをGKE上に構築
kubectl apply -f todo-api.yml

sleep 20
# TODO WebをGKE上に構築
kubectl apply -f todo-web.yml
