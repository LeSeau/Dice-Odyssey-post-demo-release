class_name CardPileOpener
extends TextureButton

@export var counter: Label
@export var card_pile: CardPile : set = set_card_pile
# Optional hover tooltip (styled like every other tooltip in the game). Left empty by the
# Draw/Discard/Exhaust pile instances in battle.tscn - only the top-bar DeckButton sets
# this ("Deck", run.tscn), so those in-combat piles are unaffected.
@export var hover_tooltip_text: String = ""

var _tooltip: Node
var _punch_tween: Tween


# Small "something just landed in this pile" squash, called by whatever animation delivers a
# card here (played-card fly-out, end-turn discard sweep, reshuffle mini-cards, draw dispense).
# Scales around the button's center; rapid landings restart the punch instead of stacking.
func receive_punch(strength: float = 1.18) -> void:
    pivot_offset = size / 2.0
    if _punch_tween and _punch_tween.is_valid():
        _punch_tween.kill()
    scale = Vector2.ONE
    _punch_tween = create_tween()
    _punch_tween.tween_property(self, "scale", Vector2(strength, strength), 0.06) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    _punch_tween.tween_property(self, "scale", Vector2.ONE, 0.22) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
