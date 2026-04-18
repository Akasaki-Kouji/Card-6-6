# クラス設計書（MVP版）

## 🎯 目的

本設計は「6×6カードローグライク」のMVPを実装するためのクラス構成を定義する。
ロジックとUIを分離し、拡張しやすく破綻しない構造を目指す。

---

## 🧠 設計方針

### ■ 重要原則

* 状態（State）と表示（View）を分離する
* 各クラスは単一責任にする
* データとロジックを分ける

---

## 🧩 全体構造

```
Game
 ├── BattleManager（ゲーム進行）
 ├── GridManager（盤面管理）
 ├── UnitManager（ユニット管理）
 ├── CardManager（カード管理）
 └── UI（表示）
```

---

## ⚔️ BattleManager

### ■ 役割

* ターン管理
* マナ管理
* 勝敗判定
* ゲーム進行の中心

### ■ プロパティ

```gdscript
var turn: int = 1
var mana: int = 1
var max_mana: int = 1
var current_player: String = "player"
```

---

## 🧱 GridManager

### ■ 役割

* 6×6盤面の管理
* ユニット配置・移動
* 範囲チェック

### ■ プロパティ

```gdscript
var width: int = 6
var height: int = 6
var cells = {} # "x-y" → Unit or null
```

---

### ■ メソッド

```gdscript
func get_unit(pos: Vector2i)
func set_unit(pos: Vector2i, unit)
func move_unit(from: Vector2i, to: Vector2i)
func is_in_bounds(pos: Vector2i) -> bool
func is_occupied(pos: Vector2i) -> bool
```

---

## 🧍 Unit（データクラス）

### ■ 役割

* ユニットの状態を保持する
* ロジックは持たない

### ■ プロパティ

```gdscript
var id: int
var owner: String # "player" or "enemy"

var hp: int
var max_hp: int
var attack: int
var move: int

var position: Vector2i

var has_moved: bool = false
var has_attacked: bool = false
var just_summoned: bool = true
```

---

## 👥 UnitManager

### ■ 役割

* ユニットの生成・管理
* 戦闘処理
* 死亡処理

### ■ プロパティ

```gdscript
var units: Array = []
```

---

### ■ メソッド

```gdscript
func spawn_unit(card, pos: Vector2i, owner: String)
func move_unit(unit, to: Vector2i)
func attack(attacker, target)
func remove_unit(unit)
```

---

## 🃏 Card（データ）

### ■ 役割

* カードの情報を保持

### ■ プロパティ

```gdscript
var name: String
var cost: int
var attack: int
var hp: int
var move: int
```

---

## 🎴 CardManager

### ■ 役割

* デッキ管理
* 手札管理
* カード使用処理

### ■ プロパティ

```gdscript
var hand: Array = []
var deck: Array = []
```

---

### ■ メソッド

```gdscript
func draw()
func play_card(card, pos: Vector2i)
```

---

## 🖥 UIクラス（View）

### ■ GridView

* グリッドの描画
* マスクリック検知
* 状態は持たない

---

### ■ HandView

* 手札表示
* カード選択状態

---

### ■ UnitView

* ユニット表示（HPバーなど）

---

## 🔄 状態フロー

```
カードクリック
 ↓
CardManager.select_card()

マスクリック
 ↓
BattleManagerが受け取る
 ↓
GridManagerで配置
 ↓
UnitManagerでユニット生成
 ↓
UI更新
```

---

## ⚠ 禁止事項（重要）

以下の設計は禁止：

* UnitがGridManagerを直接操作する
* UIがロジックを持つ
* Cardが直接ユニットを生成する

---

## 🧪 MVP最小構成

最低限必要なクラス：

* BattleManager
* GridManager
* Unit
* UnitManager
* Card
* CardManager

---

## 🚀 今後の拡張

MVP後に追加予定：

* 色マナ
* カード効果
* 攻撃範囲
* 状態異常
* デッキ構築

---

## 📌 備考

* シンプルさを最優先する
* まず「動く状態」を作る
* 面白さの調整は後工程
