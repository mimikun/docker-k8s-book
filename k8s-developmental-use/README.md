# 7章 Kubernetesの発展的な利用

使用しているリポジトリURL:
https://github.com/mimikun/docker-k8s-book/tree/master/k8s-developmental-use

## 7.1 Kubernetesの様々なリソース

k8sは常駐型サーバアプリ以外にもジョブサーバなど色々な使いみちがある。

### 7.1.1 Job

1つ以上のPodを作成し、指定された数のPodが正常に完了するまでを管理するリソース。
JobによるすべてのPodが正常終了しても、削除されずに保持されるので、ログや実行結果の確認が行える。
そのため、Webアプリではなく大規模計算やバッチ指向のアプリに向いている。
JobはPodを複数並列で実行することで容易にスケールアウトできる。
またPodとして実行されることでk8sのServiceと連携した処理を行いやすい。

$ touch simple-job.yml

(詳しくはsimple-job.ymlを見ること)

Jobもコンテナを使うので、spec.template以下はPod定義と同じ。
spec.parallelismでは同時に実行するPod数を指定できる。
並列でJobを実行したい時便利。
restartPolicyはPod終了時の再実行の設定。
JobリソースではAlwaysは選定できないので、NeverかOnFailureのどちらかを設定する必要がある。

実行:
$ kubectl apply -f simple-job.yml

logの確認:
$ kubectl logs -l app=pingpong
> [Sun Jun 9 14:37:42 UTC 2019] ping!
> [Sun Jun 9 14:37:52 UTC 2019] pong!
> [Sun Jun 9 14:37:42 UTC 2019] ping!
> [Sun Jun 9 14:37:52 UTC 2019] pong!
> [Sun Jun 9 14:37:42 UTC 2019] ping!
> [Sun Jun 9 14:37:52 UTC 2019] pong!

get podの結果:
> Flag --show-all has been deprecated, will be removed in an upcoming release
> NAME             READY   STATUS      RESTARTS   AGE
> pingpong-6n8zm   0/1     Completed   0          13m
> pingpong-vf46r   0/1     Completed   0          13m
> pingpong-x4rvv   0/1     Completed   0          13m

今日はここまで。

2019年6月10日

### 7.1.2 CronJob

CronJobリソースを使用すると、スケジューリングして定期的にPodを実行できる。
名前どおりcronやsystemd-timerなどで定期実行していたジョブの実行に便利
通常のサーバのcronはcrontabで管理するが、cronjobはマニフェストファイル(yml)で定義できる。
スケジューリング定義のレビューをPRで実施できるなど、構成のコード管理が便利になる。

$ touch simple-cronjob.yml

(詳しくはsimple-cronjob.ymlを見る)

最大の違いとして、spec.scheduleにcron記法でPodの起動スケジュールを定義できるようになっている。
spec.jobTemplate以下はJobリソースで定義しているPod定義のテンプレートと同じ。
cronjobのマニフェストファイルを適用すると、ジョブが作成され、指定したcronの条件に基づいたスケジュールでPodを作成する。

反映
$ kubectl apply -f simple-cronjob.yml

確認
$ kubectl get job -l app=pingpong

ログ
$ kubectl logs -l app=pingpong

定期的にジョブを実行するようなユースケースで、従来の非コンテナ環境においては、Linuxのcrontabにスケジュールとスクリプトを配置する方法が一般的だった。
k8sのcrontabを利用すれば、すべてをコンテナベースで解決できるようになる。
環境管理、構築、実行のすべてをコードで統一的に管理できる。
例のように軽量イメージのコンテナに対して実行する処理をマニフェストファイルに記述する形式もよい。
マニフェストには処理を記述せず、実装をDockerイメージに閉じ込めて実行する形式でもよい。

今日はここまで。

2019年6月11日

### 7.1.3 Secret

機密情報(証明書や鍵)をそのまま平文で書くのはやばい。
こういうとき、k8sではsecretリソースをつかうと、機密情報の文字列をbase64エンコードした状態で扱える。
例: NginxのBasic認証の機密情報を記述したファイルをSecretで管理してみる。
まずopensslを使ってユーザ名とパスワードを暗号化、base64文字列に変換してみる。

$ echo "mimikun:$(openssl passwd -quiet -crypt password)" | base64

ユーザ名: mimikun
パスワード: password
とした。

$ touch nginx-secret.yml

.htpasswdという認証情報ファイルを生成し、その内容に先程のコマンドで作った文字列を入れる。

$ kubectl apply -f nginx-secret.yml

podリソースじゃないので`get pod`では確認できない。

$ kubectl get secret

このsecretリソースを活用したNginxをつくる。

$ touch basic-auth.yml

(詳しくはbasic-auth.yml見て)

すでに作成済みのnginx-secretをvolumeとしてマウントし、nginxコンテナの/etc/nginx/secretディレクトリにマウントする。
これにより、nginx-secretで.htpasswdとして設定した文字列は、復号され、nginxコンテナ内の/etc/nginx/secret/.htpasswdに入れられる。

$ kubectl apply -f basic-auth.yml

curlでリクエスト投げてみる。

$ curl http://127.0.0.1:30060

```sh
<html>
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>nginx/1.13.12</center>
</body>
</html>
```

認証が必要と言われる。

$ curl -i --user mimikun:password http://127.0.0.1:30060

```sh
HTTP/1.1 200 OK
Server: nginx/1.13.12
Date: Tue, 11 Jun 2019 13:07:54 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 14
Connection: keep-alive

Hello Docker!!%
```

このように、Secretリソースにより、平文で大事なデータを管理しなくてよくなる。
とはいえ、これを使ったから完璧というわけではない。
仕組みを理解している人なら簡単にわかる。

今日はここまで。
