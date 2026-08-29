extends Relic

# The engine half of the rainbow archetype (Julien's "fluorescent relic", 2026-08-16): roll
# four different Dice types in one turn and it hands you a fifth type you HAVEN'T rolled -
# which, once rolled, pushes the count up again. Self-accelerating, and it pairs directly with
# Spectrum (damage per type rolled this turn).
#
# Reads Global.dice_types_rolled_this_turn, the same set Spectrum uses; player_handler clears
# it at the start of each turn.
#
# State lives in a plain script var, NOT owner.counter - RelicUI.counter is the Label node,
# not an int (same shape as crown.gd, which keeps _already_triggered locally and only writes
# owner.counter.text).

const TYPES_REQUIRED := 4

var _triggered_this_turn := false


func initialize_relic(owner: RelicUI) -> void:
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    # dice.gd emits red_dice_rolled INSTEAD of dice_rolled for the Red die - a rainbow turn
    # that includes Red would otherwise never be counted.
    if not Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.connect(_on_red_dice_rolled.bind(owner))
    if not Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.connect(_on_player_turn_started.bind(owner))
    _update_counter(owner)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    _check(owner)


func _on_red_dice_rolled(owner: RelicUI) -> void:
    _check(owner)


func _check(owner: RelicUI) -> void:
    _update_counter(owner)
    if _triggered_this_turn:
        return
    # >= rather than == so the threshold can't be skipped if two types land in one beat.
    if Global.dice_types_rolled_this_turn.size() < TYPES_REQUIRED:
        return
    var candidates := _unrolled_owned_types()
    if candidates.is_empty():
        return
    _triggered_this_turn = true
    var granted: String = candidates[randi() % candidates.size()]
    Global.set(granted + "_dice_current_amount", Global.get(granted + "_dice_current_amount") + 1)
    owner.flash()
    Events.change_current_power.emit()
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit(granted, 1)
    Events.temporary_dice_added.emit(granted)


# Types the player actually owns but has NOT rolled yet this turn - "a random different Dice".
# max_amount, not current: a type you own but have already spent this turn is still a type you
# own (same reasoning as the event dice-ownership gate).
func _unrolled_owned_types() -> Array:
    var out: Array = []
    for type in Global.DICE_TYPE_ORDER:
        if Global.dice_types_rolled_this_turn.has(type):
            continue
        if Global.get(type + "_dice_max_amount") > 0:
            out.append(type)
    return out


func _on_player_turn_started(owner: RelicUI) -> void:
    _triggered_this_turn = false
    _update_counter(owner)


func _update_counter(owner: RelicUI) -> void:
    owner.counter.text = str(mini(Global.dice_types_rolled_this_turn.size(), TYPES_REQUIRED))
    owner.counter.visible = true


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
