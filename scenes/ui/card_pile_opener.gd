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

# Counts on ARRIVAL (2026-09-24), like STS2's InvokeCardAddFinished. The pile's contents change
# the instant a card is played - the rules have already put it there - but the number used to
# tick up on release, ~0.9s before the card reached the pile, so the tick said nothing about the
# card. Every flight into a pile now calls expect_arrival() when it leaves and land_arrival() when
# it lands, and the counter shows the pile minus the cards still in the air.
# Set by BattleUI on the Exhaust pile, which stays hidden until it has actually counted a card.
var reveal_when_counted := false
var _pile_size := 0
var _in_flight := {}
var _next_token := 0
var _reveal_queued := false


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
    _pile_size = cards_amount
    _refresh_counter()


# A card is on its way here. Returns the token to land it with. The failsafe counts it anyway
# if its flight is killed before landing, so the number can never stay short.
func expect_arrival(failsafe: float = 3.2) -> int:
    _next_token += 1
    var token := _next_token
    _in_flight[token] = true
    _refresh_counter()
    if is_inside_tree():
        get_tree().create_timer(failsafe, false).timeout.connect(land_arrival.bind(token, false))
    return token


func land_arrival(token: int, punch: bool = true, strength: float = 1.18) -> void:
    if not _in_flight.has(token):
        return
    _in_flight.erase(token)
    _refresh_counter()
    if punch:
        receive_punch(strength)


# What the counter shows: the pile minus what is still flying to it. Clamped because a reshuffle
# can empty the discard while a card is still on its way there.
func shown_count() -> int:
    return maxi(_pile_size - _in_flight.size(), 0)


func cards_in_flight() -> int:
    return _in_flight.size()


func _refresh_counter() -> void:
    if counter != null:
        counter.text = str(shown_count())
    # Deferred: during a play the pile changes BEFORE the card's flight has registered itself, so
    # an immediate check would reveal the Exhaust pile for a card that has not landed yet.
    if reveal_when_counted and not visible and not _reveal_queued:
        _reveal_queued = true
        _reveal_if_counted.call_deferred()


func _reveal_if_counted() -> void:
    _reveal_queued = false
    if reveal_when_counted and shown_count() > 0:
        visible = true


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
