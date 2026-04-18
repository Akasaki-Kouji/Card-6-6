class_name UnitManager
extends Node

# ---------------------------------------------------------------------------
# シグナル
# ---------------------------------------------------------------------------
signal unit_died(unit: Unit)
signal unit_damaged(unit: Unit)
signal castle_damaged(castle: Castle)
signal game_over(winner: String)

# ---------------------------------------------------------------------------
# 依存ノード
# ---------------------------------------------------------------------------
@export var grid_manager: GridManager

# ---------------------------------------------------------------------------
# プロパティ
# ---------------------------------------------------------------------------
var units:   Array[Unit]   = []
var castles: Array[Castle] = []

var _next_id: int = 1

# ---------------------------------------------------------------------------
# 初期化
# ---------------------------------------------------------------------------
func _ready() -> void:
	assert(grid_manager != null, "UnitManager: grid_manager が未設定")


## 城を登録する（BattleManager の初期化時に呼ぶ）
func setup_castles(player_castle: Castle, enemy_castle: Castle) -> void:
	castles = [player_castle, enemy_castle]


# ---------------------------------------------------------------------------
# ユニット生成
# Card クラス実装後は spawn_from_card() を追加予定
# ---------------------------------------------------------------------------
func spawn_unit(
	owner:  String,
	hp:     int,
	atk:    int,
	mov:    int,
	pos:    Vector2i
) -> Unit:
	var unit := Unit.new(_next_id, owner, hp, atk, mov, pos)
	_next_id += 1
	units.append(unit)
	grid_manager.set_unit(pos, unit)
	print("UnitManager: 召喚 %s" % unit)
	return unit


# ---------------------------------------------------------------------------
# 攻撃処理
# ---------------------------------------------------------------------------

## attacker が target_pos を攻撃する
## target_pos にいるのがユニットか城かを自動判定する
func attack(attacker: Unit, target_pos: Vector2i) -> void:
	# ユニットへの攻撃
	var target_unit := grid_manager.get_unit(target_pos) as Unit
	if target_unit != null:
		_attack_unit(attacker, target_unit)
		return

	# 城への攻撃
	var target_castle := get_castle_at(target_pos)
	if target_castle != null:
		_attack_castle(attacker, target_castle)
		return

	push_warning("UnitManager.attack: target_pos に攻撃対象が存在しない pos=%s" % target_pos)


func _attack_unit(attacker: Unit, target: Unit) -> void:
	target.hp -= attacker.attack
	attacker.has_attacked = true

	print("UnitManager: %s → %s ダメージ%d (残HP %d)" % [
		_coord(attacker.position), _coord(target.position),
		attacker.attack, target.hp
	])

	if not target.is_alive():
		_remove_unit(target)
	else:
		unit_damaged.emit(target)


func _attack_castle(attacker: Unit, target: Castle) -> void:
	target.take_damage(attacker.attack)
	attacker.has_attacked = true

	print("UnitManager: %s → %s城 ダメージ%d (残HP %d)" % [
		_coord(attacker.position), target.owner,
		attacker.attack, target.hp
	])

	castle_damaged.emit(target)

	if target.is_destroyed():
		var winner := "enemy" if target.owner == "player" else "player"
		print("UnitManager: ゲーム終了 勝者=%s" % winner)
		game_over.emit(winner)


# ---------------------------------------------------------------------------
# ユニット除去（死亡処理）
# ---------------------------------------------------------------------------
func _remove_unit(unit: Unit) -> void:
	units.erase(unit)
	grid_manager.remove_unit(unit.position)
	print("UnitManager: 死亡 %s" % unit)
	unit_died.emit(unit)


# ---------------------------------------------------------------------------
# 攻撃可能マス取得
# 隣接マスにいる敵ユニット＋敵城マスを返す
# ---------------------------------------------------------------------------
func get_attackable_positions(attacker: Unit) -> Array[Vector2i]:
	# 召喚したターンは攻撃不可
	if attacker.just_summoned:
		return []

	var result: Array[Vector2i] = []

	for neighbor: Vector2i in grid_manager.get_adjacent_cells(attacker.position):
		# 敵ユニット
		var unit := grid_manager.get_unit(neighbor) as Unit
		if unit != null and unit.owner != attacker.owner:
			result.append(neighbor)
			continue
		# 敵城
		var castle := get_castle_at(neighbor)
		if castle != null and castle.owner != attacker.owner:
			result.append(neighbor)

	return result


# ---------------------------------------------------------------------------
# ユーティリティ
# ---------------------------------------------------------------------------

## pos にある城を返す（なければ null）
func get_castle_at(pos: Vector2i) -> Castle:
	for castle: Castle in castles:
		if castle.contains(pos):
			return castle
	return null


## ターン開始時に全ユニットのフラグをリセットする
func reset_all_units() -> void:
	for unit: Unit in units:
		unit.reset_turn()


func _coord(pos: Vector2i) -> String:
	return "%d-%d" % [pos.y + 1, pos.x + 1]
