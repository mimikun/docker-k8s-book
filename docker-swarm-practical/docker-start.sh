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


## 4. Swarmによる実践的なアプリケーション構築
# 専用のoverlayネットワークを構築
docker container exec -it manager \
docker network create --driver=overlay --attachable todoapp

# MySQL Serviceの構築 p122
ghq get github.com/gihyodocker/tododb
C-g tododb
# dockerイメージをビルド
docker image build -t ch04/tododb:latest .
# tagをつける
docker image tag ch04/tododb:latest localhost:5000/ch04/tododb:latest
# registryにpush
docker image push localhost:5000/ch04/tododb:latest

# Swarmでtodo-mysqlをデプロイ
docker container exec -it manager docker stack deploy -c /stack/todo-mysql.yml todo_mysql
# 確認
docker container exec -it manager docker service ls

# 4.2.7 MySQLコンテナを確認し、初期データ投入
# Masterコンテナがどのノードにあるか見る
docker container exec -it manager docker service ps todo_mysql_master --no-trunc \
--filter "desired-state=running"
# NODE(692149889de1)とID(dn4m5nbahpufksp0rduujwdxd)をコピーし、これを実行
docker container exec -it 692149889de1 \
docker container exec -it todo_mysql_master.1.dn4m5nbahpufksp0rduujwdxd bash
# 上記のコマンドを出すスクリプト
docker container exec -it manager \
docker service ps todo_mysql_master \
--no-trunc \
--filter "desired-state=running" \
--format "docker container exec -it {{.Node}} docker container exec -it {{.Name}}.{{.ID}} bash"

# masterコンテナでinit-data.shを実行し,初期データ投入
docker container exec -it 692149889de1 \
docker container exec -it todo_mysql_master.1.dn4m5nbahpufksp0rduujwdxd \
init-data.sh

# DB確認
docker container exec -it 692149889de1 \
docker container exec -it todo_mysql_master.1.dn4m5nbahpufksp0rduujwdxd \
mysql -u gihyo -pgihyo tododb
mysql> SELECT * FROM todo LIMIT 1\G

# Slaveにもデータがあるか確認
# Slaveコンテナ入るためのコマンド出すスクリプト
docker container exec -it manager \
docker service ps todo_mysql_slave \
--no-trunc \
--filter "desired-state=running" \
--format "docker container exec -it {{.Node}} docker container exec -it {{.Name}}.{{.ID}} bash"
# コンテナ入ってSQL投げる
docker container exec -it 6aa0ee42bbec \
docker container exec -it todo_mysql_slave.1.xsgo29kl2xxi57508nd4w1sa2 \
mysql -u gihyo -pgihyo tododb
mysql> SELECT * FROM todo LIMIT 1\G
# 意図した通り、master slaveに同じデータ入ってるか見る

## 4.3 API Serviceの構築
ghq get -p gihyodocker/todoapi
#C-g -> gihyodocker/todoapi
docker image build -t ch04/todoapi:latest .
docker image tag ch04/todoapi:latest localhost:5000/ch04/todoapi:latest
docker image push localhost:5000/ch04/todoapi:latest
# Swarm上でtodoapiサービスを実行
touch stack/todo-app.yml
docker container exec -it manager docker stack deploy -c /stack/todo-app.yml todo_app
## 4.4 Nginxの構築
ghq get -p gihyodocker/todonginx
C-g gihyongi
## とりあえずはAPIの前におくnginxをつくる
docker image build -t ch04/nginx:latest .
docker image tag ch04/nginx:latest localhost:5000/ch04/nginx:latest
docker image push localhost:5000/ch04/nginx:latest
# todo-app.ymlを更新し、nginxを通してアクセスできるようにする
# todo_appのStackを更新
docker container exec -it manager docker stack deploy -c /stack/todo-app.yml todo_app

# 4.5 Webの構築
ghq get -p gihyodocker/todoweb
C-g gihyow
docker image build -t ch04/todoweb:latest .
docker image tag ch04/todoweb:latest localhost:5000/ch04/todoweb:latest
docker image push localhost:5000/ch04/todoweb:latest

## 4.5.3 静的ファイルの扱いを工夫する
# 静的ファイルなassetsファイルはWeb通さずNginxから直接レスポンスするようにする
C-g gihyongi
cp etc/nginx/conf.d/public.conf.tmpl etc/nginx/conf.d/nuxt.conf.tmpl
#p156を見て追記する
cp Dockerfile Dockerfile-nuxt
#p156, 157を見て追記する
# イメージをビルドする
docker image build -f Dockerfile-nuxt -t ch04/nginx-nuxt:latest .
docker image tag ch04/nginx-nuxt:latest localhost:5000/ch04/nginx-nuxt:latest
docker image push localhost:5000/ch04/nginx-nuxt:latest

# コンテナ間でのボリューム共有
# assets用のdocker volumeを作成しnginxとtodowebで共有する
## 4.5.4 Nginxを通してアクセスできるようにする
touch stack/todo-frontend.yml
#p158見て書く
