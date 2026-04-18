class_name Unit
extends RefCounted

# ---------------------------------------------------------------------------
# プロパティ
# ---------------------------------------------------------------------------
var id:       int
var owner:    String    # "player" or "enemy"

var hp:       int
var max_hp:   int
var attack:   int
var move:     int

var position: Vector2i

var has_moved:    bool = false
var has_attacked: bool = false
var just_summoned: bool = true

# ---------------------------------------------------------------------------
# コンストラクタ
# ---------------------------------------------------------------------------
func _init(
	p_id:     int,
	p_owner:  String,
	p_hp:     int,
	p_attack: int,
	p_move:   int,
	p_pos:    Vector2i
) -> void:
	id       = p_id
	owner    = p_owner
	hp       = p_hp
	max_hp   = p_hp
	attack   = p_attack
	move     = p_move
	position = p_pos


# ---------------------------------------------------------------------------
# ターン開始時にリセット（BattleManager から呼ぶ）
# ---------------------------------------------------------------------------
func reset_turn() -> void:
	has_moved     = false
	has_attacked  = false
	just_summoned = false


# ---------------------------------------------------------------------------
# 生存判定
# ---------------------------------------------------------------------------
func is_alive() -> bool:
	return hp > 0


# ---------------------------------------------------------------------------
# デバッグ用文字列
# ---------------------------------------------------------------------------
func _to_string() -> String:
	return "[Unit id=%d owner=%s pos=%s hp=%d/%d atk=%d mov=%d]" % [
		id, owner, position, hp, max_hp, attack, move
	]
