extends Relic

const SCOUT2_CARD = preload("res://characters/warrior/cards/card_scout2.tres")

var triggered_this_turn := false

func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.change_current_power.connect(_on_change_current_power.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started)

func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:
    _try_trigger(owner)

func _on_change_current_power(owner: RelicUI) -> void:
    _try_trigger(owner)

func _try_trigger(owner: RelicUI) -> void:
    if triggered_this_turn or Global.roll_value <= 12:
        return
    triggered_this_turn = true
    owner.flash()
    # SCOUT2_CARD is a shared preloaded singleton - duplicate before handing it out so
    # triggering this relic across multiple fights/turns never emits the SAME Card object
    # into hand twice (see flywheel.gd for the full rationale).
    Events.add_card_to_hand_requested.emit(SCOUT2_CARD.duplicate())

func _on_player_turn_started() -> void:
    triggered_this_turn = false

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.change_current_power.is_connected(_on_change_current_power):
        Events.change_current_power.disconnect(_on_change_current_power)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
