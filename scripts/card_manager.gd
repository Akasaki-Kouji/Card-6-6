class_name CardManager
extends Node

# ---------------------------------------------------------------------------
# シグナル
# ---------------------------------------------------------------------------

## 手札が変化したとき（ドロー・使用後）に発火する
signal hand_changed(hand: Array[Card])
## デッキ残枚数が変化したとき
signal deck_count_changed(remaining: int)
## デッキが空になったとき
signal deck_emptied

# ---------------------------------------------------------------------------
# プロパティ
# ---------------------------------------------------------------------------
var hand: Array[Card] = []
var deck: Array[Card] = []

# ---------------------------------------------------------------------------
# 初期化
# ---------------------------------------------------------------------------
func _ready() -> void:
	_build_deck()


## 初期手札を配る（全ノードの add_child が完了した後に呼ぶ）
func draw_initial_hand(count: int = 5) -> void:
	for i in count:
		draw_card()
	deck_count_changed.emit(deck.size())


func _build_deck() -> void:
	# 兵士×4、重装兵×3、斥候×3 の計10枚デッキ
	for i in 4:
		deck.append(Card.make_soldier())
	for i in 3:
		deck.append(Card.make_heavy())
	for i in 3:
		deck.append(Card.make_scout())
	deck.shuffle()
	print("CardManager: デッキ生成 %d枚" % deck.size())


# ---------------------------------------------------------------------------
# ドロー
# ---------------------------------------------------------------------------
func draw_card() -> Card:
	if deck.is_empty():
		print("CardManager: デッキが空のためドロー不可")
		deck_emptied.emit()
		return null

	var card: Card = deck.pop_back()
	hand.append(card)
	hand_changed.emit(hand)
	deck_count_changed.emit(deck.size())
	if deck.is_empty():
		deck_emptied.emit()
	print("CardManager: ドロー %s（手札 %d枚 デッキ残 %d枚）" % [card, hand.size(), deck.size()])
	return card


# ---------------------------------------------------------------------------
# 手札から除去（カード使用後に呼ぶ）
# ---------------------------------------------------------------------------
func remove_from_hand(card: Card) -> void:
	hand.erase(card)
	hand_changed.emit(hand)
	print("CardManager: 手札から除去 %s（残り %d枚）" % [card, hand.size()])
