# wire_connection_tester.rb

Raspberry Pi を親機として、コネクターやケーブルの結線を確認します。

以下のインストールが必要。

* `sudo apt install i2c-tools ruby ruby-dev`
* `sudo gem install i2c`
    * 必要なら `--http-proxy=<HTTP_PROXY>`

まず装置を Raspberry Pi と接続します。

次に、装置に確認対象となるコネクターやケーブルを接続します。

そして、以下のように実行すると、結線パターンのマトリックス図と結線パターンを HEX で表現した「signature」を表示します。

```
$ ruby wire_connection_tester.rb
```

結線パターンが「`signature.dat`」に登録された既知のものであれば、その名前のリストを表示します。

「`signatures.dat`」に以下の形式で行を追加することで結線パターンを登録することができます。

```
<HEX 結線パターン><空白文字><結線パターン名>
```

以下のように「`--loop`」オプションを付けると、繰り返しモードになります。

```
$ ruby wire_connection_tester.rb --loop
```

繰り返しモードでは、押しボタンを押す毎に結線パターンチェックを実行します。

＃ たまに I2C 通信エラーで落ちるようで、その場合は再度起動し直します。

