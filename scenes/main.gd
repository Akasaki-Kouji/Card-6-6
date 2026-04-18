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
	_place_grid(root_vbox, grid_view, battle_manager)
	_place_hand(root_vbox, hand_view, card_manager)
	_place_topbar(root_vbox, battle_manager, player_castle, enemy_castle)
	_place_right_panel(root_vbox, battle_manager)

	_show_castle(grid_view, player_castle)
	_show_castle(grid_view, enemy_castle)

	var enemy := unit_manager.spawn_unit("enemy", 2, 2, 1, Vector2i(2, 1))
	_show_unit(grid_view, enemy)

	card_manager.draw_initial_hand()

	# ---- ゲームオーバーUI ----
	_build_gameover_ui(battle_manager)

	# ---- ゲーム開始（最初のチャージフェーズ）----
	battle_manager.begin_first_turn()


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
	bar.custom_minimum_size.y = 80

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
	vbox.add_theme_constant_override("separation", 4)

	# 城名 + HP を1行で表示
	var header_row := _make_hbox(6)
	header_row.alignment = BoxContainer.ALIGNMENT_BEGIN if align_left \
		else BoxContainer.ALIGNMENT_END

	var name_lbl := _make_label(label_text, color, 11)
	header_row.add_child(name_lbl)

	var hp_lbl := _make_label("%d / %d" % [hp, max_hp], Color(color.r, color.g, color.b, 0.7), 10)
	hp_lbl.name = "HpLabel"
	header_row.add_child(hp_lbl)
	vbox.add_child(header_row)

	# HPバー（細め）
	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(0.0, 5.0)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(color.r, color.g, color.b, 0.12)
	bar_style.set_corner_radius_all(2)
	bar_bg.add_theme_stylebox_override("panel", bar_style)

	var bar_inner := HBoxContainer.new()
	bar_inner.add_theme_constant_override("separation", 0)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(color.r, color.g, color.b, 0.65)
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

	# 敵ターン中オーバーレイ
	var enemy_overlay := _make_label("⏳ 相手のターン処理中…", C_TEXT3, 9)
	enemy_overlay.name = "EnemyOverlay"
	enemy_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_overlay.visible = false
	vbox.add_child(enemy_overlay)

	# シグナル接続
	battle_manager.turn_changed.connect(func(player: String, turn: int) -> void:
		var is_player := player == "player"
		phase_lbl.text = "自分のターン" if is_player else "相手のターン"
		phase_lbl.add_theme_color_override("font_color", C_BLUE if is_player else C_RED)
		turn_lbl.text = "ターン %d" % turn
		enemy_overlay.visible = not is_player
	)

	return vbox


func _rebuild_mana_pool_display(row: HBoxContainer, pool: Dictionary) -> void:
	for child in row.get_children():
		child.queue_free()

	const COLORS: Array = ["red", "blue", "green", "white", "black"]
	const NAMES:  Array = ["赤", "青", "緑", "白", "黒"]
	const COLS: Array = [
		Color("#e85555"), Color("#4a9eff"), Color("#48bb78"),
		Color("#dde8f0"), Color("#8892a4")
	]

	for i in COLORS.size():
		var color_key: String = COLORS[i]
		var count: int        = pool.get(color_key, 0)
		var col: Color        = COLS[i]

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var name_lbl := Label.new()
		name_lbl.text = NAMES[i]
		name_lbl.add_theme_color_override("font_color", col)
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.text = str(count)
		count_lbl.add_theme_color_override("font_color", col if count > 0 else Color(col.r, col.g, col.b, 0.3))
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(count_lbl)

		row.add_child(vbox)


func _place_grid(vbox: VBoxContainer, grid_view: GridView, battle_manager: BattleManager = null) -> void:
	# Main エリア（3カラム）を TopBar の直後に追加
	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(main_hbox)

	# 左サイドパネル（バトルログ・折りたたみ可能）
	var left := _make_panel(BG2, Color.TRANSPARENT, BORDER)
	left.name = "LeftPanel"
	left.custom_minimum_size.x = 220
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# パネル内部：トグル列 ＋ ログ列 の横並び
	var left_hbox := HBoxContainer.new()
	left_hbox.add_theme_constant_override("separation", 0)
	left_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# トグルボタン列（常時表示・28px固定）
	var toggle_col := VBoxContainer.new()
	toggle_col.custom_minimum_size.x = 28
	toggle_col.add_theme_constant_override("separation", 0)

	var toggle_btn := Button.new()
	toggle_btn.text = "◀"
	toggle_btn.custom_minimum_size = Vector2(28.0, 28.0)
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.add_theme_font_size_override("font_size", 10)
	var toggle_style := StyleBoxFlat.new()
	toggle_style.bg_color = Color(1, 1, 1, 0.04)
	toggle_style.set_border_width_all(0)
	toggle_btn.add_theme_stylebox_override("normal", toggle_style)
	toggle_btn.add_theme_stylebox_override("hover",  toggle_style)
	toggle_btn.add_theme_color_override("font_color", C_TEXT3)
	toggle_col.add_child(toggle_btn)

	var toggle_spacer := Control.new()
	toggle_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	toggle_col.add_child(toggle_spacer)
	left_hbox.add_child(toggle_col)

	# ログコンテンツ列（折りたたみ対象）
	var log_content := VBoxContainer.new()
	log_content.name = "LogContent"
	log_content.add_theme_constant_override("separation", 4)
	log_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_content.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var log_title := _make_label("BATTLE LOG", C_TEXT3, 10)
	log_content.add_child(log_title)

	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var log_list := VBoxContainer.new()
	log_list.name = "LogList"
	log_list.add_theme_constant_override("separation", 2)
	log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_list)
	log_content.add_child(log_scroll)
	left_hbox.add_child(_make_margin(log_content, 8))

	left.add_child(left_hbox)
	main_hbox.add_child(left)

	# トグル動作
	var log_expanded := true
	toggle_btn.pressed.connect(func() -> void:
		log_expanded = not log_expanded
		log_content.visible        = log_expanded
		left.custom_minimum_size.x = 220 if log_expanded else 30
		toggle_btn.text            = "◀" if log_expanded else "▶"
	)

	if battle_manager != null:
		battle_manager.battle_log.connect(func(msg: String) -> void:
			var entry := _make_label(msg, C_TEXT2, 9)
			entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			log_list.add_child(entry)
			if log_list.get_child_count() > 30:
				log_list.get_child(0).queue_free()
			await get_tree().process_frame
			log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)
		)

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
	right.custom_minimum_size.x = 340
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_label := _make_label("ACTIONS", C_TEXT3, 10)
	right.add_child(_make_margin(right_label, 12))
	main_hbox.add_child(right)


func _place_hand(vbox: VBoxContainer, hand_view: HandView, card_manager: CardManager) -> void:
	var hand_panel := _make_panel(BG2, Color.TRANSPARENT, Color(1, 1, 1, 0.08))
	hand_panel.name = "HandPanel"
	hand_panel.custom_minimum_size.y = 272

	var sep := ColorRect.new()
	sep.color = BORDER2
	sep.custom_minimum_size.y = 1
	sep.size_flags_horizontal  = Control.SIZE_EXPAND_FILL

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)

	# ヘッダー行：手札ラベル ＋ デッキ残枚数
	var header_row := _make_hbox(8)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var header := _make_label("手　札", C_TEXT2, 11)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	var deck_lbl := _make_label("デッキ %d枚" % card_manager.deck.size(), C_TEXT3, 9)
	deck_lbl.name = "DeckCountLabel"
	header_row.add_child(deck_lbl)

	inner.add_child(header_row)
	hand_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(hand_view)

	hand_panel.add_child(_make_vbox_with(sep, _make_margin(inner, 10)))
	vbox.add_child(hand_panel)

	# デッキ残枚数の更新
	card_manager.deck_count_changed.connect(func(remaining: int) -> void:
		deck_lbl.text = "デッキ %d枚" % remaining
	)
	card_manager.deck_emptied.connect(func() -> void:
		deck_lbl.text = "デッキ切れ"
		deck_lbl.add_theme_color_override("font_color", C_RED)
	)


func _place_right_panel(vbox: VBoxContainer, battle_manager: BattleManager) -> void:
	var right := vbox.get_node("MainHBox/RightPanel") as PanelContainer
	if right == null:
		return

	for child in right.get_children():
		child.queue_free()

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ── チャージセクション（チャージ待機中のみ表示）──
	var charge_section := _make_charge_section(battle_manager)
	charge_section.visible = false
	inner.add_child(charge_section)

	# ── 区切り線（チャージ中のみ表示）──
	var charge_sep := ColorRect.new()
	charge_sep.color = Color(1, 1, 1, 0.08)
	charge_sep.custom_minimum_size.y = 1
	charge_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	charge_sep.visible = false
	inner.add_child(charge_sep)

	# ── マナプール表示 ──
	var mana_section := VBoxContainer.new()
	mana_section.add_theme_constant_override("separation", 6)

	var mana_title := _make_label("MANA POOL", C_TEXT3, 12)
	mana_section.add_child(mana_title)

	var mana_row := _make_hbox(8)
	mana_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mana_section.add_child(mana_row)
	_rebuild_mana_pool_display_panel(mana_row, battle_manager.mana_pool)

	var mana_sep := ColorRect.new()
	mana_sep.color = Color(1, 1, 1, 0.08)
	mana_sep.custom_minimum_size.y = 1
	mana_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mana_section.add_child(mana_sep)
	inner.add_child(mana_section)

	battle_manager.mana_pool_changed.connect(func(pool: Dictionary) -> void:
		_rebuild_mana_pool_display_panel(mana_row, pool)
	)

	# ── ユニット情報ブロック ──
	var unit_section := VBoxContainer.new()
	unit_section.add_theme_constant_override("separation", 6)

	var unit_title := _make_label("UNIT INFO", C_TEXT3, 10)
	unit_section.add_child(unit_title)

	var no_unit_lbl := _make_label("選択なし", C_TEXT3, 10)
	no_unit_lbl.name = "NoUnitLabel"
	unit_section.add_child(no_unit_lbl)

	var detail := _make_unit_detail_block()
	detail.name    = "UnitDetail"
	detail.visible = false
	unit_section.add_child(detail)

	inner.add_child(unit_section)

	# スペーサー
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	# ── ターン終了ボタン ──
	var action_title := _make_label("ACTIONS", C_TEXT3, 10)
	inner.add_child(action_title)

	var end_btn := _make_end_turn_button()
	end_btn.pressed.connect(battle_manager.end_turn)
	inner.add_child(end_btn)

	right.add_child(_make_margin(inner, 12))

	# チャージ中はセクション表示 + ターン終了ボタン無効化
	battle_manager.charge_requested.connect(func() -> void:
		charge_section.visible = true
		charge_sep.visible     = true
		end_btn.disabled       = true
		end_btn.modulate       = Color(1, 1, 1, 0.3)
		_refresh_charge_counts(charge_section, battle_manager.mana_pool)
	)

	# ユニット情報更新
	battle_manager.unit_selection_changed.connect(func(unit: Unit) -> void:
		if unit == null:
			no_unit_lbl.visible = true
			detail.visible      = false
		else:
			no_unit_lbl.visible = false
			detail.visible      = true
			_update_unit_detail(detail, unit)
	)

	# チャージ完了後にセクションを隠してボタン復活
	battle_manager.mana_pool_changed.connect(func(_pool: Dictionary) -> void:
		if not battle_manager._charge_pending:
			charge_section.visible = false
			charge_sep.visible     = false
			end_btn.disabled       = false
			end_btn.modulate       = Color.WHITE
	)


const _MANA_COLORS: Array = ["red",      "blue",     "green",    "white",    "black"]
const _MANA_NAMES:  Array = ["赤",       "青",       "緑",       "白",       "黒"]
const _MANA_COLS:   Array = [
	Color("#e85555"), Color("#4a9eff"), Color("#48bb78"),
	Color("#dde8f0"), Color("#8892a4")
]


func _make_charge_section(battle_manager: BattleManager) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# ヘッダー（点滅感のある強調ラベル）
	var title := _make_label("▶ マナチャージ", C_GOLD, 10)
	vbox.add_child(title)

	# 5色ボタン（1行）
	var row := _make_hbox(4)
	row.name = "ChargeRow1"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for i in _MANA_COLORS.size():
		var color_key: String = _MANA_COLORS[i]
		var col: Color        = _MANA_COLS[i]

		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", 2)
		btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn := Button.new()
		btn.text              = _MANA_NAMES[i]
		btn.custom_minimum_size = Vector2(0.0, 46.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode        = Control.FOCUS_NONE

		var bs := StyleBoxFlat.new()
		bs.bg_color     = Color(col.r, col.g, col.b, 0.12)
		bs.border_color = Color(col.r, col.g, col.b, 0.55)
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", bs)

		var bs_hover := bs.duplicate() as StyleBoxFlat
		bs_hover.bg_color     = Color(col.r, col.g, col.b, 0.28)
		bs_hover.border_color = Color(col.r, col.g, col.b, 0.9)
		btn.add_theme_stylebox_override("hover", bs_hover)

		btn.add_theme_color_override("font_color", col)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(battle_manager.charge_mana.bind(color_key))
		btn_vbox.add_child(btn)

		# 所持数ラベル
		var cnt := _make_label("0", Color(col.r, col.g, col.b, 0.6), 8)
		cnt.name = "cnt_%s" % color_key
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_vbox.add_child(cnt)

		row.add_child(btn_vbox)

	vbox.add_child(row)
	return vbox


func _refresh_charge_counts(charge_section: VBoxContainer, pool: Dictionary) -> void:
	for i in _MANA_COLORS.size():
		var color_key: String = _MANA_COLORS[i]
		var cnt: Label = charge_section.find_child("cnt_%s" % color_key, true, false) as Label
		if cnt != null:
			cnt.text = "%d所持" % pool.get(color_key, 0)


func _rebuild_mana_pool_display_panel(row: HBoxContainer, pool: Dictionary) -> void:
	for child in row.get_children():
		child.queue_free()

	for i in _MANA_COLORS.size():
		var color_key: String = _MANA_COLORS[i]
		var col: Color        = _MANA_COLS[i]
		var count: int        = pool.get(color_key, 0)

		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# 色付きボックス
		var gem := Panel.new()
		gem.custom_minimum_size = Vector2(36.0, 36.0)
		gem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(col.r, col.g, col.b, 0.25 if count > 0 else 0.07)
		s.border_color = Color(col.r, col.g, col.b, 0.7  if count > 0 else 0.2)
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		gem.add_theme_stylebox_override("panel", s)

		# 数字を gem の中央に
		var num := Label.new()
		num.text = str(count)
		num.add_theme_color_override("font_color", col if count > 0 else Color(col.r, col.g, col.b, 0.3))
		num.add_theme_font_size_override("font_size", 15)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gem.add_child(num)

		# 色名ラベル
		var name_lbl := Label.new()
		name_lbl.text = _MANA_NAMES[i]
		name_lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.6))
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		block.add_child(gem)
		block.add_child(name_lbl)
		row.add_child(block)


func _make_unit_detail_block() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# オーナーバッジ
	var owner_lbl := _make_label("", C_BLUE, 11)
	owner_lbl.name = "OwnerLabel"
	owner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(owner_lbl)

	# 区切り線
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size.y = 1
	sep.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	vbox.add_child(sep)

	# HP バー
	var hp_row := _make_hbox(6)
	var hp_key := _make_label("HP", C_TEXT3, 9)
	var hp_val := _make_label("", C_BLUE, 11)
	hp_val.name = "HpValue"
	hp_row.add_child(hp_key)
	hp_row.add_child(hp_val)
	vbox.add_child(hp_row)

	var hp_bar_bg := Panel.new()
	hp_bar_bg.custom_minimum_size = Vector2(0.0, 5.0)
	hp_bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.15)
	bg_s.set_corner_radius_all(2)
	hp_bar_bg.add_theme_stylebox_override("panel", bg_s)
	var hp_fill := ColorRect.new()
	hp_fill.name  = "HpFill"
	hp_fill.color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.7)
	hp_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_fill.size_flags_stretch_ratio = 1.0
	var fill_hbox := HBoxContainer.new()
	fill_hbox.add_theme_constant_override("separation", 0)
	fill_hbox.add_child(hp_fill)
	hp_bar_bg.add_child(fill_hbox)
	vbox.add_child(hp_bar_bg)

	# ATK / MOV
	for pair: Array in [["ATK", "AtkValue", C_RED], ["MOV", "MovValue", C_TEXT2]]:
		var row := _make_hbox(6)
		var key := _make_label(pair[0], C_TEXT3, 9)
		var val := _make_label("", pair[2], 11)
		val.name = pair[1]
		row.add_child(key)
		row.add_child(val)
		vbox.add_child(row)

	# 移動/攻撃フラグ
	var flags_row := _make_hbox(4)
	flags_row.name = "FlagsRow"
	vbox.add_child(flags_row)

	return vbox


func _update_unit_detail(detail: VBoxContainer, unit: Unit) -> void:
	var is_player := unit.owner == "player"
	var color     := C_BLUE if is_player else C_RED

	var owner_lbl: Label     = detail.find_child("OwnerLabel", true, false) as Label
	var hp_val:    Label     = detail.find_child("HpValue",    true, false) as Label
	var hp_fill:   ColorRect = detail.find_child("HpFill",     true, false) as ColorRect
	var atk_val:   Label     = detail.find_child("AtkValue",   true, false) as Label
	var mov_val:   Label     = detail.find_child("MovValue",   true, false) as Label
	var flags_row: HBoxContainer = detail.find_child("FlagsRow", true, false) as HBoxContainer

	owner_lbl.text = "自軍ユニット" if is_player else "敵ユニット"
	owner_lbl.add_theme_color_override("font_color", color)

	hp_val.text = "%d / %d" % [unit.hp, unit.max_hp]
	hp_val.add_theme_color_override("font_color", color)
	hp_fill.color = Color(color.r, color.g, color.b, 0.7)
	hp_fill.size_flags_stretch_ratio = float(unit.hp) / float(unit.max_hp) if unit.max_hp > 0 else 0.0

	atk_val.text = str(unit.attack)
	mov_val.text = str(unit.move)

	# 移動/攻撃フラグバッジ
	for child in flags_row.get_children():
		child.queue_free()
	if unit.has_moved:
		flags_row.add_child(_make_flag_badge("移動済", C_TEXT3))
	if unit.has_attacked:
		flags_row.add_child(_make_flag_badge("攻撃済", C_TEXT3))
	if unit.just_summoned:
		flags_row.add_child(_make_flag_badge("召喚直後", C_GOLD))


func _make_flag_badge(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 8)
	return lbl


# ---------------------------------------------------------------------------
# ゲームオーバーUI
# ---------------------------------------------------------------------------
func _build_gameover_ui(battle_manager: BattleManager) -> void:
	var overlay := ColorRect.new()
	overlay.color   = Color(0.0, 0.0, 0.0, 0.75)
	overlay.visible = false
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 24)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var result_lbl := Label.new()
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_color_override("font_color", C_TEXT)
	result_lbl.add_theme_font_size_override("font_size", 64)
	center.add_child(result_lbl)

	var restart_btn := Button.new()
	restart_btn.text = "もう一度プレイ"
	restart_btn.custom_minimum_size = Vector2(200.0, 48.0)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color     = BG3
	btn_style.border_color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.5)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(8)
	restart_btn.add_theme_stylebox_override("normal", btn_style)
	restart_btn.add_theme_color_override("font_color", C_BLUE)
	restart_btn.add_theme_font_size_override("font_size", 16)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(restart_btn)
	center.add_child(btn_row)

	restart_btn.pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)

	battle_manager.game_ended.connect(func(winner: String) -> void:
		result_lbl.text = "勝　利！" if winner == "player" else "敗　北…"
		result_lbl.add_theme_color_override("font_color", C_BLUE if winner == "player" else C_RED)
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
