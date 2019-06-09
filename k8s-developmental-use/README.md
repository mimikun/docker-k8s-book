# 7章 Kubernetesの発展的な利用

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
