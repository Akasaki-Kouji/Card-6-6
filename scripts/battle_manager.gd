class_name BattleManager
extends Node

# ---------------------------------------------------------------------------
# シグナル
# ---------------------------------------------------------------------------
signal turn_changed(current_player: String, turn: int)
signal mana_pool_changed(pool: Dictionary)
signal charge_requested()
signal game_ended(winner: String)
signal unit_selection_changed(unit: Unit)
signal battle_log(message: String)

# ---------------------------------------------------------------------------
# 依存ノード
# ---------------------------------------------------------------------------
@export var grid_manager:  GridManager
@export var grid_view:     GridView
@export var unit_manager:  UnitManager
@export var card_manager:  CardManager
@export var hand_view:     HandView

# ---------------------------------------------------------------------------
# 定数
# ---------------------------------------------------------------------------
enum State { IDLE, CARD_SELECTED, UNIT_SELECTED }

const COLOR_MOVE   := Color(0.3, 1.0, 0.3, 0.7)
const COLOR_ATTACK := Color(1.0, 0.3, 0.3, 0.7)
const COLOR_DEPLOY := Color(0.3, 0.5, 1.0, 0.7)

const MANA_COLORS := ["red", "blue", "green", "white", "black"]

# ---------------------------------------------------------------------------
# プロパティ
# ---------------------------------------------------------------------------
var current_state:    State  = State.IDLE
var selected_unit:    Unit   = null
var selected_card:    Card   = null

var current_player:   String = "player"
var turn:             int    = 1

var mana_pool:        Dictionary = {}   # 現在使えるマナ（ターン開始時にmaxへリセット）
var mana_pool_max:    Dictionary = {}   # 蓄積された最大マナ（チャージで増加、減らない）
var enemy_mana_pool:     Dictionary = {}
var enemy_mana_pool_max: Dictionary = {}

var _charge_pending:  bool   = false
var _game_over:       bool   = false

# ---------------------------------------------------------------------------
# 初期化
# ---------------------------------------------------------------------------
func _ready() -> void:
	assert(grid_manager != null, "BattleManager: grid_manager が未設定")
	assert(grid_view    != null, "BattleManager: grid_view が未設定")
	assert(unit_manager != null, "BattleManager: unit_manager が未設定")
	assert(card_manager != null, "BattleManager: card_manager が未設定")
	assert(hand_view    != null, "BattleManager: hand_view が未設定")

	for color in MANA_COLORS:
		mana_pool[color]           = 0
		mana_pool_max[color]       = 0
		enemy_mana_pool[color]     = 0
		enemy_mana_pool_max[color] = 0

	grid_view.cell_clicked.connect(_on_cell_clicked)
	hand_view.card_selected.connect(_on_card_selected)
	card_manager.hand_changed.connect(_on_hand_changed)
	unit_manager.unit_died.connect(_on_unit_died)
	unit_manager.unit_damaged.connect(_on_unit_damaged)
	unit_manager.castle_damaged.connect(_on_castle_damaged)
	unit_manager.game_over.connect(_on_game_over)


## ゲーム開始時に呼ぶ（最初のチャージフェーズを開始する）
func begin_first_turn() -> void:
	_charge_pending = true
	turn_changed.emit(current_player, turn)
	mana_pool_changed.emit(mana_pool)
	charge_requested.emit()
	battle_log.emit("── ターン %d 開始 ──" % turn)


# ---------------------------------------------------------------------------
# チャージ
# ---------------------------------------------------------------------------

## プレイヤーが色を選んでマナをチャージする
func charge_mana(color: String) -> void:
	if not _charge_pending or _game_over:
		return
	mana_pool_max[color] = mana_pool_max.get(color, 0) + 1
	_restore_mana_pool()   # 最大値にリセット
	_charge_pending = false
	mana_pool_changed.emit(mana_pool)
	hand_view.apply_mana_filter(mana_pool)
	battle_log.emit("%s マナをチャージ (最大%d個)" % [_color_name(color), mana_pool_max[color]])


func _restore_mana_pool() -> void:
	for color in MANA_COLORS:
		mana_pool[color] = mana_pool_max[color]


# ---------------------------------------------------------------------------
# ターンシステム
# ---------------------------------------------------------------------------
func end_turn() -> void:
	if _game_over or current_player != "player" or _charge_pending:
		return
	_reset_state()
	current_player = "enemy"
	battle_log.emit("── 自分のターン終了 ──")
	_run_enemy_turn()


func _start_player_turn() -> void:
	current_player = "player"
	turn          += 1

	unit_manager.reset_all_units()
	card_manager.draw_card()
	_restore_mana_pool()   # ターン開始時に現在マナを最大値に戻す

	_charge_pending = true
	turn_changed.emit(current_player, turn)
	mana_pool_changed.emit(mana_pool)
	charge_requested.emit()
	battle_log.emit("── ターン %d 開始 ──" % turn)


# ---------------------------------------------------------------------------
# 敵ターン（簡易AI）
# ---------------------------------------------------------------------------
func _run_enemy_turn() -> void:
	battle_log.emit("── 敵のターン ──")
	unit_manager.reset_all_units()

	# 敵がランダムに1色チャージ（最大プールに加算してリセット）
	var charge_color: String = MANA_COLORS[randi() % MANA_COLORS.size()]
	enemy_mana_pool_max[charge_color] = enemy_mana_pool_max.get(charge_color, 0) + 1
	for color in MANA_COLORS:
		enemy_mana_pool[color] = enemy_mana_pool_max[color]

	_enemy_summon()

	var enemy_units: Array[Unit] = []
	for unit: Unit in unit_manager.units:
		if unit.owner == "enemy":
			enemy_units.append(unit)

	for unit: Unit in enemy_units:
		if unit.is_alive():
			_enemy_act(unit)

	_start_player_turn()


func _enemy_summon() -> void:
	var deployable := grid_manager.get_deployable_cells("enemy")
	if deployable.is_empty():
		return

	var candidates: Array[Card] = []
	for c: Card in [Card.make_soldier(), Card.make_heavy(), Card.make_scout()]:
		if _can_afford(c, enemy_mana_pool):
			candidates.append(c)
	if candidates.is_empty():
		return

	candidates.shuffle()
	var card: Card     = candidates[0]
	var pos: Vector2i  = deployable[randi() % deployable.size()]
	_consume_mana(card, enemy_mana_pool)
	var unit := unit_manager.spawn_unit("enemy", card.hp, card.attack, card.move, pos)
	_refresh_cell(unit.position)
	battle_log.emit("敵が %s を召喚" % card.card_name)


func _enemy_act(unit: Unit) -> void:
	var attackable := unit_manager.get_attackable_positions(unit)
	if not attackable.is_empty():
		unit_manager.attack(unit, attackable[0])
		return

	if not unit.has_moved:
		var target := _find_nearest_player_target(unit.position)
		if target != Vector2i(-1, -1):
			var movable := grid_manager.get_movable_cells(unit.position, unit.move)
			if not movable.is_empty():
				var best := _closest_cell_to(movable, target)
				_execute_move(unit, best)

	if not unit.has_attacked:
		attackable = unit_manager.get_attackable_positions(unit)
		if not attackable.is_empty():
			unit_manager.attack(unit, attackable[0])


func _find_nearest_player_target(from: Vector2i) -> Vector2i:
	var nearest:  Vector2i = Vector2i(-1, -1)
	var min_dist: int      = 999

	for unit: Unit in unit_manager.units:
		if unit.owner != "player":
			continue
		var dist: int = abs(unit.position.x - from.x) + abs(unit.position.y - from.y)
		if dist < min_dist:
			min_dist = dist
			nearest  = unit.position

	for castle: Castle in unit_manager.castles:
		if castle.owner != "player":
			continue
		for pos: Vector2i in castle.cells:
			var dist: int = abs(pos.x - from.x) + abs(pos.y - from.y)
			if dist < min_dist:
				min_dist = dist
				nearest  = pos

	return nearest


func _closest_cell_to(cells: Array[Vector2i], target: Vector2i) -> Vector2i:
	var best:     Vector2i = cells[0]
	var min_dist: int      = abs(best.x - target.x) + abs(best.y - target.y)
	for cell: Vector2i in cells:
		var dist: int = abs(cell.x - target.x) + abs(cell.y - target.y)
		if dist < min_dist:
			min_dist = dist
			best     = cell
	return best


# ---------------------------------------------------------------------------
# メイン入力ハンドラ
# ---------------------------------------------------------------------------
func _on_cell_clicked(pos: Vector2i) -> void:
	if _game_over or current_player != "player" or _charge_pending:
		return
	match current_state:
		State.IDLE:
			_handle_idle(pos)
		State.CARD_SELECTED:
			_handle_card_selected(pos)
		State.UNIT_SELECTED:
			_handle_unit_selected(pos)


# ---------------------------------------------------------------------------
# IDLE 状態
# ---------------------------------------------------------------------------
func _handle_idle(pos: Vector2i) -> void:
	var unit := grid_manager.get_unit(pos) as Unit
	if unit != null and unit.owner == "player":
		_select_unit(unit)


# ---------------------------------------------------------------------------
# CARD_SELECTED 状態
# ---------------------------------------------------------------------------
func _on_card_selected(card: Card) -> void:
	if _game_over or current_player != "player" or _charge_pending:
		return
	if not _can_afford(card, mana_pool):
		battle_log.emit("マナ不足: %s" % card.card_name)
		return
	if current_state == State.CARD_SELECTED and selected_card == card:
		_reset_state()
		return
	_select_card(card)


func _select_card(card: Card) -> void:
	selected_card = card
	selected_unit = null
	current_state = State.CARD_SELECTED

	var deployable := grid_manager.get_deployable_cells("player")
	grid_view.reset_highlight()
	grid_view.highlight_cells(deployable, COLOR_DEPLOY)
	hand_view.highlight_selected(card)


func _handle_card_selected(pos: Vector2i) -> void:
	var deployable := grid_manager.get_deployable_cells("player")
	if pos in deployable:
		_play_card(selected_card, pos)
		_reset_state()
	else:
		_reset_state()


func _play_card(card: Card, pos: Vector2i) -> void:
	_consume_mana(card, mana_pool)
	mana_pool_changed.emit(mana_pool)
	var unit := unit_manager.spawn_unit("player", card.hp, card.attack, card.move, pos)
	_refresh_cell(unit.position)
	card_manager.remove_from_hand(card)
	hand_view.apply_mana_filter(mana_pool)
	battle_log.emit("%s を %s に召喚" % [card.card_name, _coord(pos)])


func _on_hand_changed(hand: Array[Card]) -> void:
	hand_view.update_hand(hand)
	hand_view.apply_mana_filter(mana_pool)


# ---------------------------------------------------------------------------
# UNIT_SELECTED 状態
# ---------------------------------------------------------------------------
func _handle_unit_selected(pos: Vector2i) -> void:
	if pos == selected_unit.position:
		_reset_state()
		return

	var attackable := unit_manager.get_attackable_positions(selected_unit)
	if pos in attackable:
		_execute_attack(selected_unit, pos)
		_reset_state()
		return

	var movable := get_movable_cells(selected_unit)
	if pos in movable:
		_execute_move(selected_unit, pos)
		_select_unit(selected_unit)
		return

	var unit := grid_manager.get_unit(pos) as Unit
	if unit != null and unit.owner == "player":
		_select_unit(unit)
		return

	_reset_state()


func _select_unit(unit: Unit) -> void:
	selected_unit = unit
	current_state = State.UNIT_SELECTED

	var movable    := get_movable_cells(unit)
	var attackable := unit_manager.get_attackable_positions(unit)

	grid_view.reset_highlight()
	grid_view.highlight_cells(movable,    COLOR_MOVE)
	grid_view.highlight_cells(attackable, COLOR_ATTACK)
	unit_selection_changed.emit(unit)


func get_movable_cells(unit: Unit) -> Array[Vector2i]:
	if unit.has_moved:
		return []
	return grid_manager.get_movable_cells(unit.position, unit.move)


# ---------------------------------------------------------------------------
# 移動・攻撃の実行
# ---------------------------------------------------------------------------
func _execute_move(unit: Unit, to: Vector2i) -> void:
	var from: Vector2i = unit.position
	var ok := grid_manager.move_unit(from, to)
	if not ok:
		push_warning("BattleManager._execute_move: 失敗 %s→%s" % [from, to])
		return
	unit.position  = to
	unit.has_moved = true
	_refresh_cell(from)
	_refresh_cell(to)
	var who := "自軍" if unit.owner == "player" else "敵軍"
	battle_log.emit("%s %s→%s" % [who, _coord(from), _coord(to)])


func _execute_attack(attacker: Unit, target_pos: Vector2i) -> void:
	if attacker.has_attacked:
		return
	unit_manager.attack(attacker, target_pos)


# ---------------------------------------------------------------------------
# UnitManager シグナルハンドラ
# ---------------------------------------------------------------------------
func _on_unit_died(unit: Unit) -> void:
	var who := "自軍" if unit.owner == "player" else "敵軍"
	battle_log.emit("%s ユニット撃破 (%s)" % [who, _coord(unit.position)])
	_refresh_cell(unit.position)


func _on_unit_damaged(unit: Unit) -> void:
	_refresh_cell(unit.position)
	if unit == selected_unit:
		unit_selection_changed.emit(unit)


func _on_castle_damaged(castle: Castle) -> void:
	var who := "自城" if castle.owner == "player" else "敵城"
	battle_log.emit("%s にダメージ (残HP %d)" % [who, castle.hp])
	for pos: Vector2i in castle.cells:
		_refresh_cell(pos)


func _on_game_over(winner: String) -> void:
	_game_over = true
	_reset_state()
	game_ended.emit(winner)


# ---------------------------------------------------------------------------
# セル表示の更新
# ---------------------------------------------------------------------------
func _refresh_cell(pos: Vector2i) -> void:
	var unit := grid_manager.get_unit(pos) as Unit
	if unit != null:
		grid_view.set_unit_cell(pos, unit.owner == "player", unit.hp, unit.max_hp, unit.attack)
		return
	var castle := unit_manager.get_castle_at(pos)
	if castle != null:
		grid_view.set_castle_cell(pos, castle.owner == "player", castle.hp)
		return
	grid_view.clear_cell(pos)


# ---------------------------------------------------------------------------
# 状態リセット
# ---------------------------------------------------------------------------
func _reset_state() -> void:
	current_state = State.IDLE
	selected_unit = null
	selected_card = null
	grid_view.reset_highlight()
	hand_view.reset_highlight()
	unit_selection_changed.emit(null)


# ---------------------------------------------------------------------------
# マナユーティリティ
# ---------------------------------------------------------------------------
func _can_afford(card: Card, pool: Dictionary) -> bool:
	for color in card.cost:
		if pool.get(color, 0) < card.cost[color]:
			return false
	return true


func _consume_mana(card: Card, pool: Dictionary) -> void:
	for color in card.cost:
		pool[color] -= card.cost[color]


func _color_name(color: String) -> String:
	match color:
		"red":   return "赤"
		"blue":  return "青"
		"green": return "緑"
		"white": return "白"
		"black": return "黒"
	return color


func _coord(pos: Vector2i) -> String:
	return "%d-%d" % [pos.y + 1, pos.x + 1]
