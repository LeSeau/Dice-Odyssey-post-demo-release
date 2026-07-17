class_name CardPileOpener
extends TextureButton

@export var counter: Label
@export var card_pile: CardPile : set = set_card_pile
# Optional hover tooltip (styled like every other tooltip in the game). Left empty by the
# Draw/Discard/Exhaust pile instances in battle.tscn - only the top-bar DeckButton sets
# this ("Deck", run.tscn), so those in-combat piles are unaffected.
@export var hover_tooltip_text: String = ""

var _tooltip: Node

func set_card_pile(new_value: CardPile) -> void:
    card_pile = new_value

    if not card_pile.card_pile_size_changed.is_connected(_on_card_pile_size_changed):
        card_pile.card_pile_size_changed.connect(_on_card_pile_size_changed)
        _on_card_pile_size_changed(card_pile.cards.size())

func _on_card_pile_size_changed(cards_amount: int) -> void:
    counter.text = str(cards_amount)


func _on_mouse_entered() -> void:
    if hover_tooltip_text == "":
        return
    if is_instance_valid(_tooltip):
        _tooltip.queue_free()
    _tooltip = IconTooltip.spawn_below(self, hover_tooltip_text)


func _on_mouse_exited() -> void:
    if is_instance_valid(_tooltip):
        _tooltip.queue_free()
        _tooltip = null
