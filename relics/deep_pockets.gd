extends Relic

# "I still have dice but nothing left to play" is the exact state Julien described on
# 2026-09-08, so this relic exists only inside it: it pays when the hand runs dry while a die
# is still unspent, and stays silent in a fight where the hand keeps up. That makes it
# self-regulating - it cannot inflate a deck that is already drawing enough.
#
# ⚠️ The deferred check is load-bearing. Card.play() emits card_played as its FIRST line, and
# card_ui.play() only calls _fly_to_discard_and_free() afterwards - that is what reparents the
# CardUI out of the Hand. Counting the hand in the same frame would still see the card that
# was just played, so the relic would never fire. call_deferred runs after the reparent.
#
# Firing while the last card is still flying to the discard pile is correct, not a race: the
# card is gone from the player's point of view, they cannot play it any more.
#
# Once per turn, and the flag lives on Global rather than on this resource because relics are
# shared .tres singletons (relic_handler assigns them without duplicating), so per-turn state
# stored here would leak across runs. Cleared in dice_interface.gd next to
# charged_dice_this_turn.

const CARDS := 2


func initialize_relic(owner: RelicUI) -> void:
    Events.card_played.connect(_on_card_played.bind(owner))


func _on_card_played(_card: Card, owner: RelicUI) -> void:
    _check.call_deferred(owner)


func _check(owner: RelicUI) -> void:
    if Global.deep_pockets_fired_this_turn:
        return
    # A die left to spend is half the condition - an empty hand with an empty dice pool is
    # just a finished turn, and refilling it there would hand out free cards every turn.
    if Global.dice_pool_empty():
        return
    if not is_instance_valid(owner) or not owner.is_inside_tree():
        return
    var hand: Node = owner.get_tree().get_first_node_in_group("hand")
    if hand == null:
        return
    for child in hand.get_children():
        if child is CardUI:
            return
    Global.deep_pockets_fired_this_turn = true
    owner.flash()
    Events.draw_card.emit(CARDS)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.card_played.is_connected(_on_card_played):
        Events.card_played.disconnect(_on_card_played)
