class_name CardPile
extends Resource

signal card_pile_size_changed(cards_amount)

@export var cards: Array[Card] = []


func empty() -> bool:
    return cards.is_empty()


func draw_card() -> Card:
    var card = cards.pop_front()
    card_pile_size_changed.emit(cards.size())
    return card


func add_card(card: Card) -> void:
    cards.append(card)
    card_pile_size_changed.emit(cards.size())


# Slots the card at `index` (0 = drawn next) instead of at the back - draw_card() pops the
# FRONT, so add_card() on the draw pile would bury a card at the bottom. Used by the
# draw-pile junk injector to shuffle an enemy's card in at a random depth.
func insert_card(card: Card, index: int) -> void:
    cards.insert(clampi(index, 0, cards.size()), card)
    card_pile_size_changed.emit(cards.size())
    
func remove_card(card: Card) -> void:
    cards.erase(card)
    card_pile_size_changed.emit(cards.size())


func replace_card(old_card: Card, new_card: Card) -> void:
    var index := cards.find(old_card)
    if index != -1:
        cards[index] = new_card
    card_pile_size_changed.emit(cards.size())



func shuffle() -> void:
    cards.shuffle()


func clear() -> void:
    cards.clear()
    card_pile_size_changed.emit(cards.size())


func _to_string() -> String:
    var _card_strings: PackedStringArray = []
    for i in range(cards.size()):
        _card_strings.append("%s: %s" % [i+1, cards[i].id])
    return "\n".join(_card_strings)
