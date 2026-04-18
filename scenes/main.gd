extends Control

# ---------------------------------------------------------------------------
# カラーパレット（HTMLモックアップに準拠）
# ---------------------------------------------------------------------------
const BG      := Color("#0e1117")
const BG2     := Color("#161b26")
const BG3     := Color("#1e2535")
const BORDER  := Color(1.0, 1.0, 1.0, 0.08)
const BORDER2 := Color(1.0, 1.0, 1.0, 0.15)
const C_TEXT  := Color("#e8eaf0")
const C_TEXT2 := Color("#8892a4")
const C_TEXT3 := Color("#4a5568")
const C_RED   := Color("#e85555")
const C_BLUE  := Color("#4a9eff")
const C_GREEN := Color("#48bb78")
const C_GOLD  := Color("#f6c344")

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)

	# ---- ゲームノード生成 ----
	var grid_manager   := GridManager.new()
	var grid_view      := GridView.new()
	var unit_manager   := UnitManager.new()
	var card_manager   := CardManager.new()
	var hand_view      := HandView.new()
	var battle_manager := BattleManager.new()

	unit_manager.grid_manager   = grid_manager
	battle_manager.grid_manager = grid_manager
	battle_manager.grid_view    = grid_view
	battle_manager.unit_manager = unit_manager
	battle_manager.card_manager = card_manager
	battle_manager.hand_view    = hand_view

	# ロジックノードは先に add_child（_ready でシグナルを接続するため）
	add_child(grid_manager)
	add_child(unit_manager)
	add_child(card_manager)
	add_child(battle_manager)

	# ---- UI レイアウト構築 ----
	var root_vbox := _build_root_layout()
	add_child(root_vbox)
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ---- ゲーム初期化（城はUI構築より先に作る）----
	var player_castle := Castle.new("player")
	var enemy_castle  := Castle.new("enemy")
	unit_manager.setup_castles(player_castle, enemy_castle)

	# ---- 各エリアに UI ノードを配置 ----
	_place_grid(root_vbox, grid_view)
	_place_hand(root_vbox, hand_view)
	_place_topbar(root_vbox, battle_manager, player_castle, enemy_castle)
	_place_right_panel(root_vbox, battle_manager)

	_show_castle(grid_view, player_castle)
	_show_castle(grid_view, enemy_castle)

	var enemy := unit_manager.spawn_unit("enemy", 2, 2, 1, Vector2i(2, 1))
	_show_unit(grid_view, enemy)

	card_manager.draw_initial_hand()

	# ---- ゲームオーバーUI ----
	_build_gameover_ui(battle_manager)


# ---------------------------------------------------------------------------
# レイアウト骨格
# ---------------------------------------------------------------------------
func _build_root_layout() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = "RootLayout"
	vbox.add_theme_constant_override("separation", 0)
	return vbox


func _place_topbar(vbox: VBoxContainer, battle_manager: BattleManager,
		player_castle: Castle, enemy_castle: Castle) -> void:
	var bar := _make_panel(BG2, Color.TRANSPARENT, Color(1, 1, 1, 0.08))
	bar.custom_minimum_size.y = 64

	# 下部ボーダー
	var sep := ColorRect.new()
	sep.color = BORDER2
	sep.custom_minimum_size.y = 1
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ── 内部レイアウト: 左城HP ｜ 中央情報 ｜ 右城HP ──
	var inner := _make_hbox(0)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 左：自城HP ブロック
	var player_hp_block := _make_castle_hp_block(
		"自　城", player_castle.hp, Castle.MAX_HP, C_BLUE, true
	)
	player_hp_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(player_hp_block)

	# 中央：ターン・マナ
	var center_block := _make_center_info_block(battle_manager)
	inner.add_child(center_block)

	# 右：敵城HP ブロック
	var enemy_hp_block := _make_castle_hp_block(
		"敵　城", enemy_castle.hp, Castle.MAX_HP, C_RED, false
	)
	enemy_hp_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(enemy_hp_block)

	bar.add_child(_make_vbox_with(_make_margin(inner, 10), sep))

	# シグナルで城HP更新（Fill は PanelContainer/HBoxContainer の子）
	var p_fill: ColorRect = player_hp_block.find_child("Fill",  true, false) as ColorRect
	var e_fill: ColorRect = enemy_hp_block.find_child("Fill",   true, false) as ColorRect
	var p_lbl:  Label     = player_hp_block.find_child("HpLabel", true, false) as Label
	var e_lbl:  Label     = enemy_hp_block.find_child("HpLabel",  true, false) as Label

	battle_manager.unit_manager.castle_damaged.connect(func(castle: Castle) -> void:
		var ratio: float = float(castle.hp) / float(Castle.MAX_HP)
		if castle.owner == "player":
			p_lbl.text = "%d / %d" % [castle.hp, Castle.MAX_HP]
			p_fill.size_flags_stretch_ratio = ratio
		else:
			e_lbl.text = "%d / %d" % [castle.hp, Castle.MAX_HP]
			e_fill.size_flags_stretch_ratio = ratio
	)

	vbox.add_child(bar)
	vbox.move_child(bar, 0)


func _make_castle_hp_block(
	label_text: String, hp: int, max_hp: int, color: Color, align_left: bool
) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	var lbl := _make_label(label_text, color, 10)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if align_left \
		else HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(lbl)

	var hp_lbl := _make_label("%d / %d" % [hp, max_hp], Color(color.r, color.g, color.b, 0.8), 10)
	hp_lbl.name = "HpLabel"
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if align_left \
		else HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hp_lbl)

	# HPバー
	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(0.0, 6.0)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(color.r, color.g, color.b, 0.15)
	bar_style.set_corner_radius_all(3)
	bar_bg.add_theme_stylebox_override("panel", bar_style)

	var bar_inner := HBoxContainer.new()
	bar_inner.add_theme_constant_override("separation", 0)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(color.r, color.g, color.b, 0.7)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_stretch_ratio = float(hp) / float(max_hp)
	bar_inner.add_child(fill)

	bar_bg.add_child(bar_inner)
	vbox.add_child(bar_bg)

	return vbox


func _make_center_info_block(battle_manager: BattleManager) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size.x = 200.0

	# フェーズバッジ
	var phase_lbl := _make_label("自分のターン", C_BLUE, 11)
	phase_lbl.name = "PhaseLabel"
	phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(phase_lbl)

	# ターン番号
	var turn_lbl := _make_label("ターン 1", C_TEXT2, 10)
	turn_lbl.name = "TurnLabel"
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(turn_lbl)

	# マナクリスタル行
	var mana_row := _make_hbox(3)
	mana_row.name = "ManaRow"
	mana_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_rebuild_mana_crystals(mana_row, battle_manager.mana, battle_manager.max_mana)
	vbox.add_child(mana_row)

	# シグナル接続
	battle_manager.turn_changed.connect(func(player: String, turn: int) -> void:
		phase_lbl.text = "自分のターン" if player == "player" else "相手のターン"
		phase_lbl.add_theme_color_override("font_color", C_BLUE if player == "player" else C_RED)
		turn_lbl.text = "ターン %d" % turn
		_rebuild_mana_crystals(mana_row, battle_manager.mana, battle_manager.max_mana)
	)
	battle_manager.mana_updated.connect(func(mana: int, max_mana: int) -> void:
		_rebuild_mana_crystals(mana_row, mana, max_mana)
	)

	return vbox


func _rebuild_mana_crystals(row: HBoxContainer, mana: int, max_mana: int) -> void:
	for child in row.get_children():
		child.queue_free()
	for i in max_mana:
		var filled := i < mana
		var p := Panel.new()
		p.custom_minimum_size = Vector2(10.0, 10.0)
		var s := StyleBoxFlat.new()
		s.bg_color = C_BLUE if filled else Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.2)
		s.set_corner_radius_all(2)
		p.add_theme_stylebox_override("panel", s)
		row.add_child(p)


func _place_grid(vbox: VBoxContainer, grid_view: GridView) -> void:
	# Main エリア（3カラム）を TopBar の直後に追加
	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(main_hbox)

	# 左サイドパネル（バトルログ — 後のステップで実装）
	var left := _make_panel(BG2, Color.TRANSPARENT, BORDER)
	left.name = "LeftPanel"
	left.custom_minimum_size.x = 180
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_label := _make_label("BATTLE LOG", C_TEXT3, 10)
	left.add_child(_make_margin(left_label, 12))
	main_hbox.add_child(left)

	# 中央（グリッド）
	var center := CenterContainer.new()
	center.name = "CenterArea"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	center.add_child(grid_view)
	main_hbox.add_child(center)

	# 右サイドパネル（アクション — 後のステップで実装）
	var right := _make_panel(BG2, Color.TRANSPARENT, BORDER)
	right.name = "RightPanel"
	right.custom_minimum_size.x = 170
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_label := _make_label("ACTIONS", C_TEXT3, 10)
	right.add_child(_make_margin(right_label, 12))
	main_hbox.add_child(right)


func _place_hand(vbox: VBoxContainer, hand_view: HandView) -> void:
	# 手札エリア：下部固定
	var hand_panel := _make_panel(BG2, Color.TRANSPARENT, Color(1, 1, 1, 0.08))
	hand_panel.name = "HandPanel"
	hand_panel.custom_minimum_size.y = 160

	# 上ボーダーライン
	var sep := ColorRect.new()
	sep.color = BORDER2
	sep.custom_minimum_size.y = 1
	sep.size_flags_horizontal  = Control.SIZE_EXPAND_FILL

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	var header := _make_label("手　札", C_TEXT2, 11)
	inner.add_child(header)
	hand_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(hand_view)

	hand_panel.add_child(_make_vbox_with(sep, _make_margin(inner, 10)))
	vbox.add_child(hand_panel)


func _place_right_panel(vbox: VBoxContainer, battle_manager: BattleManager) -> void:
	# 右パネルにターン終了ボタンを追加
	var right := vbox.get_node("MainHBox/RightPanel") as PanelContainer
	if right == null:
		return

	# 既存の子をクリアして作り直し
	for child in right.get_children():
		child.queue_free()

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)

	var title := _make_label("ACTIONS", C_TEXT3, 10)
	inner.add_child(title)

	# ターン終了ボタン
	var end_btn := _make_end_turn_button()
	end_btn.pressed.connect(battle_manager.end_turn)
	inner.add_child(end_btn)

	right.add_child(_make_margin(inner, 12))


# ---------------------------------------------------------------------------
# ゲームオーバーUI
# ---------------------------------------------------------------------------
func _build_gameover_ui(battle_manager: BattleManager) -> void:
	var overlay := ColorRect.new()
	overlay.color   = Color(0.0, 0.0, 0.0, 0.7)
	overlay.visible = false
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", C_TEXT)
	label.add_theme_font_size_override("font_size", 64)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(label)

	battle_manager.game_ended.connect(func(winner: String) -> void:
		label.text    = "勝　利！" if winner == "player" else "敗　北…"
		overlay.visible = true
	)


# ---------------------------------------------------------------------------
# ゲーム表示ヘルパー
# ---------------------------------------------------------------------------
func _show_castle(grid_view: GridView, castle: Castle) -> void:
	for pos: Vector2i in castle.cells:
		grid_view.set_castle_cell(pos, castle.owner == "player", castle.hp)


func _show_unit(grid_view: GridView, unit: Unit) -> void:
	grid_view.set_unit_cell(unit.position, unit.owner == "player", unit.hp, unit.max_hp)


# ---------------------------------------------------------------------------
# UI ファクトリ
# ---------------------------------------------------------------------------
func _make_panel(
	bg:         Color,
	_unused:    Color,   # 将来の shadow 用予約
	border_col: Color
) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_col
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(text: String, color: Color, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", size)
	return lbl


func _make_margin(child: Control, margin: int) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left",   margin)
	mc.add_theme_constant_override("margin_top",    margin)
	mc.add_theme_constant_override("margin_right",  margin)
	mc.add_theme_constant_override("margin_bottom", margin)
	mc.add_child(child)
	return mc


func _make_hbox(sep: int) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", sep)
	return hbox


func _make_vbox_with(a: Control, b: Control) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(a)
	vbox.add_child(b)
	return vbox


func _make_end_turn_button() -> Button:
	var btn := Button.new()
	btn.text = "ターン終了 →"
	btn.custom_minimum_size = Vector2(140.0, 40.0)

	var style := StyleBoxFlat.new()
	style.bg_color     = BG3
	style.border_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", C_GOLD)
	return btn
