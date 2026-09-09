extends Relic

# Every 3rd roll of an UNBROKEN chain draws a card (Julien, 2026-09-09, from the 09-08
# playtest: "way too many dice compared to cards"). It reads Global.roll_history, which is
# the CURRENT chain and is cleared by any Power reset or dice-type switch, so it pays for the
# thing the game is actually about - keeping the same die going - and a deck that plays a
# card after every roll never sees it.
#
# Not a duplicate of anything shipped: Metronome counts 20 dice across a FIGHT for 20 AoE
# damage, and the Conductor's Baton's old chain-of-four Charge was removed on 2026-08-31, so
# the consecutive-chain slot was empty. It also deliberately does NOT nudge Power, which is
# why the old every-3rd-die Metronome was retired (it shoved you off Exact/Multiple targets).
#
# ⚠️ The `grew` guard exists for Ricochet. A reroll re-emits dice_rolled but REWINDS
# roll_history (see Global.ricochet_reroll_active), so the chain size lands on the same
# number twice and a naive `size % EVERY == 0` would draw twice for one die. Firing only when
# the size actually GREW fixes that, and assigning streak_chain_seen unconditionally makes it
# self-heal at the first roll of a new fight without needing a reset of its own.

const EVERY := 3


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started.bind(owner))
    Events.dice_roll_reset.connect(_on_dice_roll_reset.bind(owner))
    _update_counter(owner)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    # roll_history.append() runs BEFORE dice_rolled is emitted (dice.gd), so the die that
    # just landed is already in here.
    var size: int = Global.roll_history.size()
    var grew: bool = size > Global.streak_chain_seen
    Global.streak_chain_seen = size
    _update_counter(owner)
    if not grew or size % EVERY != 0:
        return
    owner.flash()
    Events.draw_card.emit(1)


# Cycles 1..EVERY and pays on the last one rather than echoing size % EVERY raw - that would
# show "0" on the very roll that pays instead of the "3" the player is counting toward.
func _update_counter(owner: RelicUI) -> void:
    var n: int = Global.roll_history.size()
    owner.counter.text = "0" if n == 0 else str(((n - 1) % EVERY) + 1)
    owner.counter.visible = true


# The chain is what this relic counts, so the counter has to fall back to 0 the moment the
# chain breaks. Without this it would sit on "3" until the next roll and read as if the
# progress had been kept.
func _on_dice_roll_reset(owner: RelicUI) -> void:
    Global.streak_chain_seen = 0
    _update_counter(owner)


func _on_player_turn_started(owner: RelicUI) -> void:
    _update_counter(owner)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
    if Events.dice_roll_reset.is_connected(_on_dice_roll_reset):
        Events.dice_roll_reset.disconnect(_on_dice_roll_reset)
