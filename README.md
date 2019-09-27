# これは何か
MetaTrader4用のExpert Advisor(FXやCFDの自動売買プログラム)。損失許容上限までナンピン(最大４回)で頑張るEA

【注意】 このプログラムの使用は自己責任でお願いします。使用者が被るいかなる不利益に対しても当方は一切の責任を負いません。

# ライセンス
```
Copyright 2018, Teruhiko Kusunoki

Released under the MIT license
https://opensource.org/licenses/mit-license.php
```

# アイデア
- 実はエントリーのタイミングや方向は大した問題ではないのでは？
- 以下の方針で利益が出せるのでは？
  - フラフラと方向感の無い**時間帯**に
  - 比較的大きなロットで
  - 小さな値幅を狙い
  - 逆行すればナンピン(ただし損失許容上限は有り)

# ステータス
**開発中**  
まだ作り始めたとろなので、後述の極々単純なロジックを実装しただけ。
少なくとも以下の３つは今後実装する必要があるだろうなぁと思っている。
- いつエントリーするのかを決めるロジック
- 利確ターゲットに届かなさそうなポジションを手仕舞う場合のロジック
- 損失上限に達するまでに手仕舞う場合のロジック

プルリクをお待ちしておりますヽ(=´▽`=)ﾉ

# ロジック
## 時間枠
- EUR/USD 15分足

## エントリー
- 火曜〜金曜の日本時間朝６時にエントリー
- 4時間足の6MAの向きに沿って(上昇ならBUY、下落ならSELL)
- ロット数 = 口座残高 x 0.00000035
- 逆行した場合はATR(3)x3ドル毎にナンピン
  - ロット数 = 有効証拠金 x 0.00000035
  - ナンピンは最大４

## 決済
- 総含み益が口座残高の0.25%以上で利確
- 総含み損が口座残高の10%以上で損切り
- 日本時間17時には強制クローズ

# バックテスト結果
2003年6月1日〜2018年3月30日
![AveragingMaster_2003-2018_20170401](https://www.terukusu.org/test/AveragingMaster_2003-2018_20170401.gif)  
[バックテスト結果の詳細](https://www.terukusu.org/test/AveragingMaster_2003-2018_20170401.htm)
