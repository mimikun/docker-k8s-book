#!/bin/bash

# dockerコンテナを起動
docker-compose up -d

# dockerコンテナが起動してるか見る
#docker container ls

# managerコンテナをSwarmのmanagerにする
docker container exec -it manager docker swarm init

# 3つのworkerをnodeとしてSwarmクラスタに登録する
#docker container exec -it worker01 docker swarm join \
#--token SWMTKN-1-1qgvmlq2aph1fs9foa2yqbrpbsjqa9wu94mb0wayutx3wuq1qb-6hzddprg2u3l6e31icptfm7mh manager:2377

#docker container exec -it worker02 docker swarm join \
#--token SWMTKN-1-1qgvmlq2aph1fs9foa2yqbrpbsjqa9wu94mb0wayutx3wuq1qb-6hzddprg2u3l6e31icptfm7mh manager:2377

#docker container exec -it worker03 docker swarm join \
#--token SWMTKN-1-1qgvmlq2aph1fs9foa2yqbrpbsjqa9wu94mb0wayutx3wuq1qb-6hzddprg2u3l6e31icptfm7mh manager:2377

# Swarmクラスタの状態を確認
docker container exec -it manager docker node ls

# Dockerレジストリにイメージをpush
# まずtagをつける
docker image tag mimikun/echo:latest localhost:5000/example/echo:latest
# imageをpushする
docker image push localhost:5000/example/echo:latest

# worker01コンテナ上でdocker image をpullし、pullできたか docker ls で確認
docker container exec -it worker01 docker image pull registry:5000/example/echo:latest
docker container exec -it worker01 docker image ls

# Serviceを作成
docker container exec -it manager \
docker service create --replicas 1 --publish 8000:8000 --name echo registry:5000/example/echo:latest

# Serviceの一覧を見る
docker container exec -it manager docker service ls

# docker service scaleで該当Serviceのコンテナ数を増減できる
# スケールアウト時に使う
docker container exec -it manager docker service scale echo=6

# ちゃんと動いてるか見る
docker container exec -it manager docker service ps echo | grep Running

# デプロイしたServiceを消す
docker container exec -it manager docker service rm echo


## Stackについて
# クライアントと宛先のServiceを同一のoverlayネットワークに所属させる
docker container exec -it manager docker network create --driver=overlay --attachable ch03

# Stackをデプロイする
docker container exec -it manager docker stack deploy -c /stack/ch03-webapi.yml echo

# デプロイされたStackを確認する
docker container exec -it manager docker stack services echo

# Stackでデプロイされたコンテナを確認する
docker container exec -it manager docker stack ps echo

# visualizerをStackとしてデプロイ
docker container exec -it manager docker stack deploy -c /stack/visualizer.yml visualizer

# Stackの削除 デプロイしたServiceをStackごと削除
docker container exec -it manager docker stack rm echo

## ServiceをSwarmクラスタ外から利用する
# 再度ch03-webapi.ymlをecho Stackとしてデプロイ
docker container exec -it manager docker stack deploy -c /stack/ch03-webapi.yml echo

# ch03-ingress.ymlをingress Stackとしてデプロイ
docker container exec -it manager docker stack deploy -c /stack/ch03-ingress.yml ingress

# Serviceの一覧を見る
docker container exec -it manager docker service ls

# curlできるか確認
curl http://localhost:8000/
