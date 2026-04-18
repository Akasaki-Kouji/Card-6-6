class_name GridManager
extends Node

# ---------------------------------------------------------------------------
# 定数
# ---------------------------------------------------------------------------
const WIDTH: int = 6
const HEIGHT: int = 6

# ---------------------------------------------------------------------------
# プロパティ
# cells: Vector2i → Unit（またはnull）
# 座標系：x = 列(0-5)、y = 行(0-5)
#   (0,0) = 左上、(5,5) = 右下
#   設計書の「行-列」表記との対応: row=y+1, col=x+1
# ---------------------------------------------------------------------------
var cells: Dictionary = {}

# ---------------------------------------------------------------------------
# 初期化
# ---------------------------------------------------------------------------
func _ready() -> void:
	_init_cells()


func _init_cells() -> void:
	cells.clear()
	for y in HEIGHT:
		for x in WIDTH:
			cells[Vector2i(x, y)] = null


# ---------------------------------------------------------------------------
# 範囲チェック
# ---------------------------------------------------------------------------
func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < WIDTH and pos.y >= 0 and pos.y < HEIGHT


# ---------------------------------------------------------------------------
# 占有チェック
# ---------------------------------------------------------------------------
func is_occupied(pos: Vector2i) -> bool:
	return cells.get(pos) != null


# ---------------------------------------------------------------------------
# ユニット取得
# ---------------------------------------------------------------------------
func get_unit(pos: Vector2i) -> Variant:
	if not is_in_bounds(pos):
		return null
	return cells.get(pos)


# ---------------------------------------------------------------------------
# ユニット配置（直接セット）
# 外部からは spawn_unit 経由で呼ぶことを推奨
# ---------------------------------------------------------------------------
func set_unit(pos: Vector2i, unit: Variant) -> bool:
	if not is_in_bounds(pos):
		push_warning("GridManager.set_unit: 範囲外 pos=%s" % pos)
		return false
	cells[pos] = unit
	return true


# ---------------------------------------------------------------------------
# ユニット移動
# ---------------------------------------------------------------------------
func move_unit(from: Vector2i, to: Vector2i) -> bool:
	if not is_in_bounds(from):
		push_warning("GridManager.move_unit: 移動元が範囲外 from=%s" % from)
		return false
	if not is_in_bounds(to):
		push_warning("GridManager.move_unit: 移動先が範囲外 to=%s" % to)
		return false
	if cells.get(from) == null:
		push_warning("GridManager.move_unit: 移動元にユニットが存在しない from=%s" % from)
		return false
	if is_occupied(to):
		push_warning("GridManager.move_unit: 移動先に既にユニットが存在する to=%s" % to)
		return false

	cells[to] = cells[from]
	cells[from] = null
	return true


# ---------------------------------------------------------------------------
# ユニット除去
# ---------------------------------------------------------------------------
func remove_unit(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		push_warning("GridManager.remove_unit: 範囲外 pos=%s" % pos)
		return false
	cells[pos] = null
	return true


# ---------------------------------------------------------------------------
# 配置可能マス取得
# owner: "player" → 行5-6（y=4,5）、"enemy" → 行1-2（y=0,1）
# ---------------------------------------------------------------------------
func get_deployable_cells(owner: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var rows: Array = _get_deploy_rows(owner)
	for y in rows:
		for x in WIDTH:
			var pos := Vector2i(x, y)
			if not is_occupied(pos):
				result.append(pos)
	return result


func _get_deploy_rows(owner: String) -> Array:
	match owner:
		"player":
			return [4, 5]   # 設計書の行5-6
		"enemy":
			return [0, 1]   # 設計書の行1-2
		_:
			push_warning("GridManager._get_deploy_rows: 不明なオーナー '%s'" % owner)
			return []


# ---------------------------------------------------------------------------
# 隣接マス取得（上下左右）
# ---------------------------------------------------------------------------
func get_adjacent_cells(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var neighbor := pos + dir
		if is_in_bounds(neighbor):
			result.append(neighbor)
	return result


# ---------------------------------------------------------------------------
# 移動可能マス取得（BFS、move_range マス以内の空きマス）
# ---------------------------------------------------------------------------
func get_movable_cells(pos: Vector2i, move_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	# BFS
	var visited: Dictionary = {}
	var queue: Array = [{"pos": pos, "steps": 0}]
	visited[pos] = true

	while not queue.is_empty():
		var current = queue.pop_front()
		var cur_pos: Vector2i = current["pos"]
		var steps: int = current["steps"]

		if cur_pos != pos and not is_occupied(cur_pos):
			result.append(cur_pos)

		if steps >= move_range:
			continue

		for neighbor in get_adjacent_cells(cur_pos):
			if visited.has(neighbor):
				continue
			# 自マス以外で占有されていたら通過も不可
			if is_occupied(neighbor):
				visited[neighbor] = true
				continue
			visited[neighbor] = true
			queue.append({"pos": neighbor, "steps": steps + 1})

	return result


# ---------------------------------------------------------------------------
# 攻撃可能マス取得（隣接マスにいる敵ユニット）
# ---------------------------------------------------------------------------
func get_attackable_cells(pos: Vector2i, attacker_owner: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor in get_adjacent_cells(pos):
		var unit = cells.get(neighbor)
		if unit != null and unit.owner != attacker_owner:
			result.append(neighbor)
	return result


# ---------------------------------------------------------------------------
# デバッグ用：グリッド状態を文字列で出力
# ---------------------------------------------------------------------------
func debug_print() -> void:
	var lines: PackedStringArray = []
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			var unit = cells.get(Vector2i(x, y))
			if unit == null:
				row += "[ . ]"
			elif unit.owner == "player":
				row += "[ P ]"
			else:
				row += "[ E ]"
		lines.append(row)
	print("\n".join(lines))
