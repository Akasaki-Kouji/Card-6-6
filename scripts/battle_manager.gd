class_name BattleManager
extends Node

# ---------------------------------------------------------------------------
# シグナル
# ---------------------------------------------------------------------------
signal turn_changed(current_player: String, turn: int)
signal mana_updated(mana: int, max_mana: int)
signal game_ended(winner: String)
signal unit_selection_changed(unit: Unit)   # null = 選択解除

# ---------------------------------------------------------------------------
# 依存ノード
# ---------------------------------------------------------------------------
@export var grid_manager:  GridManager
@export var grid_view:     GridView
@export var unit_manager:  UnitManager
@export var card_manager:  CardManager
@export var hand_view:     HandView

# ---------------------------------------------------------------------------
# 状態定義
# ---------------------------------------------------------------------------
enum State { IDLE, CARD_SELECTED, UNIT_SELECTED }

# ---------------------------------------------------------------------------
# ハイライト色
# ---------------------------------------------------------------------------
const COLOR_MOVE   := Color(0.3, 1.0, 0.3, 0.7)
const COLOR_ATTACK := Color(1.0, 0.3, 0.3, 0.7)
const COLOR_DEPLOY := Color(0.3, 0.5, 1.0, 0.7)

# ---------------------------------------------------------------------------
# プロパティ
# ---------------------------------------------------------------------------
var current_state:   State  = State.IDLE
var selected_unit:   Unit   = null
var selected_card:   Card   = null

var current_player:  String = "player"
var turn:            int    = 1
var mana:            int    = 1
var max_mana:        int    = 1

var _game_over:      bool   = false

# ---------------------------------------------------------------------------
# 初期化
# ---------------------------------------------------------------------------
func _ready() -> void:
	assert(grid_manager != null, "BattleManager: grid_manager が未設定")
	assert(grid_view    != null, "BattleManager: grid_view が未設定")
	assert(unit_manager != null, "BattleManager: unit_manager が未設定")
	assert(card_manager != null, "BattleManager: card_manager が未設定")
	assert(hand_view    != null, "BattleManager: hand_view が未設定")

	grid_view.cell_clicked.connect(_on_cell_clicked)
	hand_view.card_selected.connect(_on_card_selected)
	card_manager.hand_changed.connect(_on_hand_changed)
	unit_manager.unit_died.connect(_on_unit_died)
	unit_manager.unit_damaged.connect(_on_unit_damaged)
	unit_manager.castle_damaged.connect(_on_castle_damaged)
	unit_manager.game_over.connect(_on_game_over)

	print("BattleManager: 初期化完了 ターン%d マナ%d/%d" % [turn, mana, max_mana])


# ---------------------------------------------------------------------------
# ターンシステム
# ---------------------------------------------------------------------------
func end_turn() -> void:
	if _game_over or current_player != "player":
		return
	print("BattleManager: プレイヤーターン終了")
	_reset_state()
	current_player = "enemy"
	_run_enemy_turn()


func _start_player_turn() -> void:
	current_player = "player"
	turn          += 1
	max_mana       = min(max_mana + 1, 10)
	mana           = max_mana

	unit_manager.reset_all_units()
	card_manager.draw_card()
	hand_view.apply_mana_filter(mana)

	turn_changed.emit(current_player, turn)
	mana_updated.emit(mana, max_mana)
	print("BattleManager: プレイヤーターン開始 ターン%d マナ%d/%d" % [turn, mana, max_mana])


# ---------------------------------------------------------------------------
# 敵ターン（簡易AI）
# ---------------------------------------------------------------------------
func _run_enemy_turn() -> void:
	print("BattleManager: 敵ターン開始")
	unit_manager.reset_all_units()

	# 敵ユニット一覧のコピーを取る（攻撃で消える可能性があるため）
	var enemy_units: Array[Unit] = []
	for unit: Unit in unit_manager.units:
		if unit.owner == "enemy":
			enemy_units.append(unit)

	for unit: Unit in enemy_units:
		if unit.is_alive():
			_enemy_act(unit)

	print("BattleManager: 敵ターン終了")
	_start_player_turn()


func _enemy_act(unit: Unit) -> void:
	# ① 攻撃できるなら攻撃
	var attackable := unit_manager.get_attackable_positions(unit)
	if not attackable.is_empty():
		unit_manager.attack(unit, attackable[0])
		return

	# ② 移動して攻撃を試みる
	if not unit.has_moved:
		var target := _find_nearest_player_target(unit.position)
		if target != Vector2i(-1, -1):
			var movable := grid_manager.get_movable_cells(unit.position, unit.move)
			if not movable.is_empty():
				var best := _closest_cell_to(movable, target)
				_execute_move(unit, best)

	# ③ 移動後に再度攻撃チェック
	if not unit.has_attacked:
		attackable = unit_manager.get_attackable_positions(unit)
		if not attackable.is_empty():
			unit_manager.attack(unit, attackable[0])


func _find_nearest_player_target(from: Vector2i) -> Vector2i:
	var nearest:  Vector2i = Vector2i(-1, -1)
	var min_dist: int      = 999

	# 自軍ユニット
	for unit: Unit in unit_manager.units:
		if unit.owner != "player":
			continue
		var dist: int = abs(unit.position.x - from.x) + abs(unit.position.y - from.y)
		if dist < min_dist:
			min_dist = dist
			nearest  = unit.position

	# 自軍城
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
	if _game_over or current_player != "player":
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
	else:
		print("BattleManager[IDLE]: 無効なクリック pos=%s" % _coord(pos))


# ---------------------------------------------------------------------------
# CARD_SELECTED 状態
# ---------------------------------------------------------------------------
func _on_card_selected(card: Card) -> void:
	if _game_over or current_player != "player":
		return
	if mana < card.cost:
		print("BattleManager: マナ不足 必要=%d 現在=%d" % [card.cost, mana])
		return
	if current_state == State.CARD_SELECTED and selected_card == card:
		print("BattleManager: カード選択解除")
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
	print("BattleManager: カード選択 %s 配置可能=%d" % [card, deployable.size()])


func _handle_card_selected(pos: Vector2i) -> void:
	var deployable := grid_manager.get_deployable_cells("player")
	if pos in deployable:
		_play_card(selected_card, pos)
		_reset_state()
	else:
		print("BattleManager[CARD_SELECTED]: 無効なマス → IDLE")
		_reset_state()


func _play_card(card: Card, pos: Vector2i) -> void:
	mana -= card.cost
	mana_updated.emit(mana, max_mana)
	var unit := unit_manager.spawn_unit("player", card.hp, card.attack, card.move, pos)
	_refresh_cell(unit.position)
	card_manager.remove_from_hand(card)
	hand_view.apply_mana_filter(mana)
	print("BattleManager: カード使用 %s マナ残り=%d" % [card, mana])


func _on_hand_changed(hand: Array[Card]) -> void:
	hand_view.update_hand(hand)
	hand_view.apply_mana_filter(mana)


# ---------------------------------------------------------------------------
# UNIT_SELECTED 状態
# ---------------------------------------------------------------------------
func _handle_unit_selected(pos: Vector2i) -> void:
	# ① 同じマスを再クリック → 選択解除
	if pos == selected_unit.position:
		print("BattleManager[UNIT_SELECTED]: 選択解除")
		_reset_state()
		return

	# ② 攻撃可能マス → 攻撃
	var attackable := unit_manager.get_attackable_positions(selected_unit)
	if pos in attackable:
		_execute_attack(selected_unit, pos)
		_reset_state()
		return

	# ③ 移動可能マス → 移動（移動後も選択維持して攻撃できる）
	var movable := get_movable_cells(selected_unit)
	if pos in movable:
		_execute_move(selected_unit, pos)
		_select_unit(selected_unit)   # ハイライトを移動後の位置で再計算
		return

	# ④ 別の自軍ユニット → 選択切替
	var unit := grid_manager.get_unit(pos) as Unit
	if unit != null and unit.owner == "player":
		print("BattleManager[UNIT_SELECTED]: 選択切替 %s → %s" % [
			_coord(selected_unit.position), _coord(pos)
		])
		_select_unit(unit)
		return

	# ⑤ それ以外 → IDLE
	print("BattleManager[UNIT_SELECTED]: 無効なクリック → IDLE pos=%s" % _coord(pos))
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

	print("BattleManager: 選択 %s 移動=%s 攻撃=%s" % [
		_coord(unit.position),
		movable.map(_coord),
		attackable.map(_coord),
	])


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
	print("BattleManager: 移動 %s → %s" % [_coord(from), _coord(to)])


func _execute_attack(attacker: Unit, target_pos: Vector2i) -> void:
	if attacker.has_attacked:
		print("BattleManager: 攻撃済みのユニット")
		return
	unit_manager.attack(attacker, target_pos)


# ---------------------------------------------------------------------------
# UnitManager シグナルハンドラ
# ---------------------------------------------------------------------------
func _on_unit_died(unit: Unit) -> void:
	_refresh_cell(unit.position)


func _on_unit_damaged(unit: Unit) -> void:
	_refresh_cell(unit.position)
	if unit == selected_unit:
		unit_selection_changed.emit(unit)


func _on_castle_damaged(castle: Castle) -> void:
	for pos: Vector2i in castle.cells:
		_refresh_cell(pos)


func _on_game_over(winner: String) -> void:
	_game_over = true
	_reset_state()
	var msg := "勝利！" if winner == "player" else "敗北..."
	print("BattleManager: ゲーム終了 → %s" % msg)
	game_ended.emit(winner)


# ---------------------------------------------------------------------------
# セル表示の更新（ユニット・城・空を自動判定）
# ---------------------------------------------------------------------------
func _refresh_cell(pos: Vector2i) -> void:
	var unit := grid_manager.get_unit(pos) as Unit
	if unit != null:
		grid_view.set_unit_cell(pos, unit.owner == "player", unit.hp, unit.max_hp)
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
# ユーティリティ
# ---------------------------------------------------------------------------
func _coord(pos: Vector2i) -> String:
	return "%d-%d" % [pos.y + 1, pos.x + 1]
