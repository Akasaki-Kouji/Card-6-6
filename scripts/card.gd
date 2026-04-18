class_name Card
extends RefCounted

# ---------------------------------------------------------------------------
# プロパティ
# ---------------------------------------------------------------------------
var card_name: String
var cost:      Dictionary   # { "red": 1, "blue": 1 } など
var attack:    int
var hp:        int
var move:      int

# ---------------------------------------------------------------------------
# コンストラクタ
# ---------------------------------------------------------------------------
func _init(
	p_name:   String,
	p_cost:   Dictionary,
	p_attack: int,
	p_hp:     int,
	p_move:   int
) -> void:
	card_name = p_name
	cost      = p_cost
	attack    = p_attack
	hp        = p_hp
	move      = p_move


# ---------------------------------------------------------------------------
# MVPサンプルカード（ファクトリ）
# ---------------------------------------------------------------------------
static func make_soldier() -> Card:
	return Card.new("兵士", {"red": 1}, 2, 2, 1)

static func make_heavy() -> Card:
	return Card.new("重装兵", {"red": 2}, 3, 4, 1)

static func make_scout() -> Card:
	return Card.new("斥候", {"green": 1}, 1, 1, 2)


# ---------------------------------------------------------------------------
# デバッグ用
# ---------------------------------------------------------------------------
func _to_string() -> String:
	return "[Card %s cost=%s atk=%d hp=%d mov=%d]" % [
		card_name, cost, attack, hp, move
	]
