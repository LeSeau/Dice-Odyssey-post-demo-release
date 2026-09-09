extends Relic

# Sixth Gear's twin on the other resource (Julien, 2026-09-09): that one turns roll VOLUME
# into Power every 8 dice, this one turns it into cards every 10. Counting across the FIGHT
# rather than the turn is the same call made for Sixth Gear on 2026-08-24 - a per-turn
# version pays nothing to a deck that spreads its rolls over several small turns.
#
# 10 and not 8 (Julien's number): cards are worth more than Power per unit, and a healthy
# five-turn fight at ~4 rolls a turn lands two payouts, so it reads as a rhythm rather than a
# passive tick.
#
# A Ricochet reroll counts as a second roll here, deliberately - fight_dice_rolled treats it
# that way for every relic (Global.ricochet_reroll_active), and unlike a chain counter it
# only ever increases, so no double-fire guard is needed.

const EVERY := 10
const CARDS := 2


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started.bind(owner))
    _update_counter(owner)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    # Both roll paths increment fight_dice_rolled BEFORE emitting, so this already counts the
    # die that just landed.
    _update_counter(owner)
    if Global.fight_dice_rolled == 0 or Global.fight_dice_rolled % EVERY != 0:
        return
    owner.flash()
    Events.draw_card.emit(CARDS)


func _update_counter(owner: RelicUI) -> void:
    var n: int = Global.fight_dice_rolled
    owner.counter.text = "0" if n == 0 else str(((n - 1) % EVERY) + 1)
    owner.counter.visible = true


func _on_player_turn_started(owner: RelicUI) -> void:
    _update_counter(owner)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
