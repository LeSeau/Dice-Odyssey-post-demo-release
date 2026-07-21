class_name CoiledSpringStatus
extends Status

# "Next turn, your first roll counts triple" - same additive trick as OpeningGambitStatus
# (the roll already counted once toward Power, so add it twice more), but armed/one-shot:
# playing the card mid-turn must NOT boost a roll made that same turn, so the spring only
# arms on the first player_turn_started AFTER being applied, and consumes itself on the
# first roll after that.
#
# Unlike Opening Gambit this disconnects its Events hooks once consumed AND whenever its
# owner is gone - a Status is a Resource, and a still-connected Events signal holds a strong
# reference to it, so without this the effect would silently persist into every later battle
# of the run (see the Opening Gambit leak note, 2026-07-20).

var _armed := false
var _owner: Node = null


func initialize_status(target: Node) -> void:
    _owner = target
    if not Events.player_turn_started.is_connected(_on_turn_started):
        Events.player_turn_started.connect(_on_turn_started)
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)


func _disconnect_all() -> void:
    if Events.player_turn_started.is_connected(_on_turn_started):
        Events.player_turn_started.disconnect(_on_turn_started)
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)


func _owner_gone() -> bool:
    return _owner == null or not is_instance_valid(_owner)


func _on_turn_started() -> void:
    if _owner_gone():
        _disconnect_all()
        return
    _armed = true


func _on_dice_rolled(_dice_type, _roll_value) -> void:
    if _owner_gone():
        _disconnect_all()
        return
    if not _armed:
        return
    Global.roll_value += Global.last_roll * 2
    Events.change_current_power.emit()
    _disconnect_all()
    # can_expire + duration 0 makes status_ui free the icon on this change.
    duration = 0


func apply_status(_target: Node) -> void:
    status_applied.emit(self)
