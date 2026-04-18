class_name HandView
extends Control

# ---------------------------------------------------------------------------
# シグナル
# ---------------------------------------------------------------------------

## カードボタンがクリックされたときに発火する
signal card_selected(card: Card)

# ---------------------------------------------------------------------------
# 定数
# ---------------------------------------------------------------------------
const CARD_W    := 136.0
const CARD_H    := 200.0
const CARD_GAP  := 10

# カラーパレット
const C_BG2     := Color("#161b26")
const C_BG3     := Color("#1e2535")
const C_BORDER  := Color(1.0, 1.0, 1.0, 0.12)
const C_TEXT    := Color("#e8eaf0")
const C_TEXT2   := Color("#8892a4")
const C_TEXT3   := Color("#4a5568")
const C_RED     := Color("#e85555")
const C_BLUE    := Color("#4a9eff")
const C_GOLD    := Color("#f6c344")

const LIFT_OFFSET := Vector2(0.0, -10.0)   # 選択時に浮き上がる量

# ---------------------------------------------------------------------------
# プロパティ
# ---------------------------------------------------------------------------
var _cards:   Dictionary = {}   # Card → Control（カード全体）
var _hbox:    HBoxContainer
var _selected: Card = null

# ---------------------------------------------------------------------------
# 初期化
# ---------------------------------------------------------------------------
func _ready() -> void:
	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", CARD_GAP)
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(_hbox)


# ---------------------------------------------------------------------------
# 手札を再描画する
# ---------------------------------------------------------------------------
func update_hand(hand: Array[Card]) -> void:
	for ctrl: Control in _cards.values():
		ctrl.queue_free()
	_cards.clear()
	_selected = null

	for card: Card in hand:
		var ctrl := _create_card_widget(card)
		_hbox.add_child(ctrl)
		_cards[card] = ctrl


# ---------------------------------------------------------------------------
# カードウィジェット生成
# ---------------------------------------------------------------------------
func _create_card_widget(card: Card) -> Control:
	# 外枠（Button で当たり判定を持つ）
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.clip_contents       = false
	btn.focus_mode          = Control.FOCUS_NONE

	# ボタン自体の描画を透明にする
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)

	# カード本体パネル（btn の子、pivot を下に設定）
	var card_panel := Panel.new()
	card_panel.name = "CardPanel"
	card_panel.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card_panel.position = Vector2.ZERO
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_theme_stylebox_override("panel", _make_card_style(false))
	btn.add_child(card_panel)

	# ── 内部レイアウト ──
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(inner)

	# ① ヘッダー行（カード名 ＋ コストバッジ）
	inner.add_child(_make_card_header(card))

	# ② アートエリア（カラーブロックで代替）
	inner.add_child(_make_art_area(card))

	# ③ ステータスグリッド（ATK / HP / MOV）
	inner.add_child(_make_stats_area(card))

	# コストバッジ（左上に絶対配置）
	var cost_badge := _make_cost_badge(card.cost)
	card_panel.add_child(cost_badge)

	btn.pressed.connect(_on_card_pressed.bind(card))
	return btn


func _make_card_header(card: Card) -> Control:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left",  6)
	mc.add_theme_constant_override("margin_top",   4)
	mc.add_theme_constant_override("margin_right", 6)
	mc.add_theme_constant_override("margin_bottom", 0)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = card.card_name
	lbl.add_theme_color_override("font_color", C_TEXT)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(lbl)
	return mc


func _make_art_area(card: Card) -> Control:
	var art := ColorRect.new()
	art.custom_minimum_size = Vector2(0.0, 64.0)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# オーナーカラーに合わせた薄い背景
	# 赤マナを含むカードは赤系、それ以外は青系
	var base: Color = C_RED if card.cost.has("red") else C_BLUE
	art.color = Color(base.r, base.g, base.b, 0.08)

	# 種別アイコン（テキスト代替）
	var icon := Label.new()
	icon.text = _card_icon(card)
	icon.add_theme_color_override("font_color", Color(base.r, base.g, base.b, 0.5))
	icon.add_theme_font_size_override("font_size", 32)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(icon)
	return art


func _make_stats_area(card: Card) -> Control:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left",   4)
	mc.add_theme_constant_override("margin_top",    4)
	mc.add_theme_constant_override("margin_right",  4)
	mc.add_theme_constant_override("margin_bottom", 4)
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for pair: Array in [
		["ATK", str(card.attack), C_RED],
		["HP",  str(card.hp),     C_BLUE],
		["MOV", str(card.move),   C_TEXT2],
	]:
		var stat_block := _make_stat_cell(pair[0], pair[1], pair[2])
		grid.add_child(stat_block)

	mc.add_child(grid)
	return mc


func _make_stat_cell(key: String, val: String, color: Color) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_color_override("font_color", C_TEXT3)
	key_lbl.add_theme_font_size_override("font_size", 9)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = val
	val_lbl.add_theme_color_override("font_color", color)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(val_lbl)

	return vbox


func _make_cost_badge(cost: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	hbox.position    = Vector2(4.0, 4.0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for color in cost:
		var count: int = cost[color]
		for i in count:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(10.0, 10.0)
			pip.mouse_filter        = Control.MOUSE_FILTER_IGNORE
			var s := StyleBoxFlat.new()
			s.bg_color = _mana_color(color)
			s.border_color = Color(1, 1, 1, 0.3)
			s.set_border_width_all(1)
			s.set_corner_radius_all(3)
			pip.add_theme_stylebox_override("panel", s)
			hbox.add_child(pip)

	return hbox


func _mana_color(color: String) -> Color:
	match color:
		"red":   return Color("#e85555")
		"blue":  return Color("#4a9eff")
		"green": return Color("#48bb78")
		"white": return Color("#dde8f0")
		"black": return Color("#8892a4")
	return Color.WHITE


func _card_icon(card: Card) -> String:
	if card.move >= 2:
		return "►"   # 斥候
	if card.hp >= 4:
		return "▣"   # 重装兵
	return "▲"        # 兵士


func _make_card_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	if selected:
		s.bg_color     = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.15)
		s.border_color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.6)
		s.set_border_width_all(2)
	else:
		s.bg_color     = C_BG3
		s.border_color = C_BORDER
		s.set_border_width_all(1)
	return s


# ---------------------------------------------------------------------------
# 入力ハンドラ
# ---------------------------------------------------------------------------
func _on_card_pressed(card: Card) -> void:
	card_selected.emit(card)


# ---------------------------------------------------------------------------
# ハイライト操作
# ---------------------------------------------------------------------------

## 選択されたカードを青枠で強調し、浮き上がらせる
func highlight_selected(card: Card) -> void:
	_selected = card
	for c: Card in _cards:
		var btn: Button  = _cards[c]
		var panel: Panel = btn.get_node("CardPanel") as Panel
		if panel == null:
			continue
		if c == card:
			panel.add_theme_stylebox_override("panel", _make_card_style(true))
			panel.position = LIFT_OFFSET
		else:
			panel.add_theme_stylebox_override("panel", _make_card_style(false))
			panel.position = Vector2.ZERO


## 払えないカードをグレーアウトする
func apply_mana_filter(mana_pool: Dictionary) -> void:
	for c: Card in _cards:
		var can_afford := true
		for color in c.cost:
			if mana_pool.get(color, 0) < c.cost[color]:
				can_afford = false
				break
		var btn: Button = _cards[c]
		btn.modulate = Color.WHITE if can_afford else Color(0.45, 0.45, 0.45, 1.0)


## 全カードのハイライトを解除する
func reset_highlight() -> void:
	_selected = null
	for c: Card in _cards:
		var btn: Button  = _cards[c]
		var panel: Panel = btn.get_node("CardPanel") as Panel
		if panel != null:
			panel.add_theme_stylebox_override("panel", _make_card_style(false))
			panel.position = Vector2.ZERO
