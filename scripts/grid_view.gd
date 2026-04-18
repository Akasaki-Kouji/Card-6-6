class_name GridView
extends Control

# ---------------------------------------------------------------------------
# シグナル
# ---------------------------------------------------------------------------
signal cell_clicked(pos: Vector2i)

# ---------------------------------------------------------------------------
# 定数
# ---------------------------------------------------------------------------
const ROWS     := 6
const COLS     := 6
const CELL_W   := 96.0
const CELL_H   := 96.0
const CELL_GAP := 6

# カラーパレット
const C_BG2    := Color("#161b26")
const C_BG3    := Color("#1e2535")
const C_BORDER := Color(1.0, 1.0, 1.0, 0.08)
const C_TEXT   := Color("#e8eaf0")
const C_TEXT2  := Color("#8892a4")
const C_TEXT3  := Color("#4a5568")
const C_RED    := Color("#e85555")
const C_BLUE   := Color("#4a9eff")

# ---------------------------------------------------------------------------
# プロパティ
# ---------------------------------------------------------------------------
var _buttons:    Dictionary = {}   # Vector2i → Button
var _bg_panels:  Dictionary = {}   # Vector2i → Panel（背景・ボーダー）
var _hl_rects:   Dictionary = {}   # Vector2i → ColorRect（ハイライト）
var _labels:     Dictionary = {}   # Vector2i → Label（中央アイコン）
var _atk_labels: Dictionary = {}   # Vector2i → Label（攻撃力）
var _hp_labels:  Dictionary = {}   # Vector2i → Label（HP数値）
var _hp_fills:   Dictionary = {}   # Vector2i → ColorRect（HPバー塗り）
var _hp_bgs:     Dictionary = {}   # Vector2i → ColorRect（HPバー背景）

# ---------------------------------------------------------------------------
# 初期化
# ---------------------------------------------------------------------------
func _ready() -> void:
	_build_grid()


func _build_grid() -> void:
	# GridView 自身のサイズを明示してCenterContainerが正しく中央寄せできるようにする
	var total_w: float = CELL_W * COLS + CELL_GAP * (COLS - 1)
	var total_h: float = CELL_H * ROWS + CELL_GAP * (ROWS - 1)
	custom_minimum_size = Vector2(total_w, total_h)

	var gc := GridContainer.new()
	gc.columns = COLS
	gc.add_theme_constant_override("h_separation", CELL_GAP)
	gc.add_theme_constant_override("v_separation", CELL_GAP)
	add_child(gc)

	for row in ROWS:
		for col in COLS:
			_build_cell(gc, Vector2i(col, row))


func _build_cell(parent: GridContainer, pos: Vector2i) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(CELL_W, CELL_H)
	btn.clip_contents = true
	btn.focus_mode    = Control.FOCUS_NONE

	# ボタン自体の描画を透明にする
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)

	# ① 背景パネル（ゾーン・ユニット種別で色が変わる）
	var bg := Panel.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _make_zone_style(pos))
	btn.add_child(bg)
	_bg_panels[pos] = bg

	# ② ハイライトオーバーレイ（半透明で重ねる）
	var hl := ColorRect.new()
	hl.color        = Color.TRANSPARENT
	hl.anchor_right  = 1.0
	hl.anchor_bottom = 1.0
	hl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hl)
	_hl_rects[pos] = hl

	# ③ 座標ラベル（左上・小）
	var coord := Label.new()
	coord.text = "%d-%d" % [pos.y + 1, pos.x + 1]
	coord.position = Vector2(3.0, 2.0)
	coord.add_theme_color_override("font_color", C_TEXT3)
	coord.add_theme_font_size_override("font_size", 8)
	coord.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(coord)

	# ④ 中央ラベル（ユニット所属）
	var lbl := Label.new()
	lbl.anchor_right  = 1.0
	lbl.anchor_bottom = 0.72
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", C_TEXT)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	_labels[pos] = lbl

	# ④-a ATKラベル（左下）
	var atk_lbl := Label.new()
	atk_lbl.anchor_left   = 0.0
	atk_lbl.anchor_right  = 0.5
	atk_lbl.anchor_top    = 0.68
	atk_lbl.anchor_bottom = 0.88
	atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	atk_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	atk_lbl.add_theme_color_override("font_color", C_RED)
	atk_lbl.add_theme_font_size_override("font_size", 11)
	atk_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_lbl.visible = false
	btn.add_child(atk_lbl)
	_atk_labels[pos] = atk_lbl

	# ④-b HPラベル（右下）
	var hp_lbl := Label.new()
	hp_lbl.anchor_left   = 0.5
	hp_lbl.anchor_right  = 1.0
	hp_lbl.anchor_top    = 0.68
	hp_lbl.anchor_bottom = 0.88
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_color_override("font_color", C_BLUE)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_lbl.visible = false
	btn.add_child(hp_lbl)
	_hp_labels[pos] = hp_lbl

	# ⑤ HPバー背景
	var hp_bg := ColorRect.new()
	hp_bg.color          = Color(1.0, 1.0, 1.0, 0.1)
	hp_bg.anchor_left    = 0.0
	hp_bg.anchor_right   = 1.0
	hp_bg.anchor_top     = 1.0
	hp_bg.anchor_bottom  = 1.0
	hp_bg.offset_left    = 4.0
	hp_bg.offset_right   = -4.0
	hp_bg.offset_top     = -5.0
	hp_bg.offset_bottom  = -2.0
	hp_bg.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	hp_bg.visible = false
	btn.add_child(hp_bg)
	_hp_bgs[pos] = hp_bg

	# ⑥ HPバー塗り（hp_bg の子）
	var hp_fill := ColorRect.new()
	hp_fill.anchor_top    = 0.0
	hp_fill.anchor_bottom = 1.0
	hp_fill.anchor_left   = 0.0
	hp_fill.anchor_right  = 1.0  # update_hp_bar() で変更
	hp_fill.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(hp_fill)
	_hp_fills[pos] = hp_fill

	btn.pressed.connect(_on_cell_pressed.bind(pos))
	parent.add_child(btn)
	_buttons[pos] = btn


# ---------------------------------------------------------------------------
# 公開 API
# ---------------------------------------------------------------------------

## ユニットを表示する
func set_unit_cell(pos: Vector2i, is_player: bool, hp: int, max_hp: int, attack: int = 0) -> void:
	if not _labels.has(pos):
		return
	var col := C_BLUE if is_player else C_RED
	_labels[pos].text = "自軍" if is_player else "敵軍"
	_labels[pos].add_theme_color_override("font_color", col)

	var atk_lbl: Label = _atk_labels[pos]
	atk_lbl.text    = "⚔%d" % attack
	atk_lbl.visible = true
	atk_lbl.offset_left  = 4.0
	atk_lbl.offset_right = 0.0

	var hp_lbl: Label = _hp_labels[pos]
	hp_lbl.text    = "♥%d" % hp
	hp_lbl.add_theme_color_override("font_color", col)
	hp_lbl.visible = true
	hp_lbl.offset_right = -4.0

	_update_hp_bar(pos, hp, max_hp, is_player)
	_update_bg_style(pos, "player_unit" if is_player else "enemy_unit")


## 城を表示する
func set_castle_cell(pos: Vector2i, is_player: bool, hp: int) -> void:
	if not _labels.has(pos):
		return
	_labels[pos].text = "自城" if is_player else "敵城"
	_labels[pos].add_theme_color_override("font_color", C_BLUE if is_player else C_RED)
	(_atk_labels[pos] as Label).visible = false
	(_hp_labels[pos]  as Label).visible = false
	_hp_bgs[pos].visible = false
	_update_bg_style(pos, "castle_player" if is_player else "castle_enemy")


## セルをクリアして基本ゾーン表示に戻す
func clear_cell(pos: Vector2i) -> void:
	if not _labels.has(pos):
		return
	_labels[pos].text = ""
	_labels[pos].add_theme_color_override("font_color", C_TEXT)
	(_atk_labels[pos] as Label).visible = false
	(_hp_labels[pos]  as Label).visible = false
	_hp_bgs[pos].visible = false
	_update_bg_style(pos, _get_zone_type(pos))


# ---------------------------------------------------------------------------
# ハイライト操作
# ---------------------------------------------------------------------------

## 指定マスをハイライトする
func highlight_cells(positions: Array, color: Color) -> void:
	for pos: Vector2i in positions:
		if _hl_rects.has(pos):
			_hl_rects[pos].color = color


## 全マスのハイライトをリセットする
func reset_highlight() -> void:
	for rect: ColorRect in _hl_rects.values():
		rect.color = Color.TRANSPARENT


# ---------------------------------------------------------------------------
# 後方互換 API（BattleManager から呼ばれる）
# ---------------------------------------------------------------------------
func set_cell_text(pos: Vector2i, text: String) -> void:
	if not _labels.has(pos):
		return
	_labels[pos].text = text


func reset_cell_text(pos: Vector2i) -> void:
	clear_cell(pos)


func get_button(pos: Vector2i) -> Button:
	return _buttons.get(pos)


# ---------------------------------------------------------------------------
# 内部処理
# ---------------------------------------------------------------------------
func _on_cell_pressed(pos: Vector2i) -> void:
	cell_clicked.emit(pos)


func _update_hp_bar(pos: Vector2i, hp: int, max_hp: int, is_player: bool) -> void:
	var hp_bg:   ColorRect = _hp_bgs[pos]
	var hp_fill: ColorRect = _hp_fills[pos]
	hp_bg.visible       = true
	hp_fill.anchor_right = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	hp_fill.color        = C_BLUE if is_player else C_RED


func _update_bg_style(pos: Vector2i, style_type: String) -> void:
	if _bg_panels.has(pos):
		_bg_panels[pos].add_theme_stylebox_override("panel", _make_style(style_type))


func _get_zone_type(pos: Vector2i) -> String:
	if pos.y <= 1:
		return "enemy_zone"
	if pos.y >= 4:
		return "deploy_zone"
	return "empty"


func _make_zone_style(pos: Vector2i) -> StyleBoxFlat:
	return _make_style(_get_zone_type(pos))


func _make_style(type: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(4)

	match type:
		"empty":
			s.bg_color     = C_BG2
			s.border_color = C_BORDER
			s.set_border_width_all(1)
		"deploy_zone":
			s.bg_color     = C_BG2.lerp(Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 1.0), 0.06)
			s.border_color = C_BORDER
			s.set_border_width_all(1)
		"enemy_zone":
			s.bg_color     = C_BG2.lerp(Color(C_RED.r, C_RED.g, C_RED.b, 1.0), 0.04)
			s.border_color = C_BORDER
			s.set_border_width_all(1)
		"castle_player":
			s.bg_color     = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.12)
			s.border_color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.35)
			s.set_border_width_all(1)
		"castle_enemy":
			s.bg_color     = Color(C_RED.r, C_RED.g, C_RED.b, 0.12)
			s.border_color = Color(C_RED.r, C_RED.g, C_RED.b, 0.35)
			s.set_border_width_all(1)
		"player_unit":
			s.bg_color     = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.12)
			s.border_color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.35)
			s.set_border_width_all(1)
		"enemy_unit":
			s.bg_color     = Color(C_RED.r, C_RED.g, C_RED.b, 0.12)
			s.border_color = Color(C_RED.r, C_RED.g, C_RED.b, 0.35)
			s.set_border_width_all(1)
		_:
			s.bg_color     = C_BG2
			s.border_color = C_BORDER
			s.set_border_width_all(1)

	return s
