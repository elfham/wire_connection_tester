# i2c_resetter

ATtiny202 を使って I2C 経由で MCP23017 をリセットします。

タクトスイッチで機器を制御するのにも使えます。

ビルドには megaTinyCore が必要です。

その他の ATtiny/ATmega や Arduino 互換機でもピン配置をいじれば動くと思います。
ATtiny85 (要 ATTinyCore) は動作確認しています。

I2C アドレスや使用するピンなどは #define で変更します。

