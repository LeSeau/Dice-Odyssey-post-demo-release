class_name PerpetualMotionStatus
extends Status

var target: Node
var used_this_turn := false

func initialize_status(_target: Node) -> void:
    target = _target
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)
    if not Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.connect(_on_player_turn_started)

func apply_status(_target: Node) -> void:
    status_applied.emit(self)

func _on_player_turn_started() -> void:
    used_this_turn = false

func _on_dice_rolled(_dice_type, _roll_value) -> void:
    if not is_instance_valid(target) or used_this_turn:
        return
    if _total_dice_left() > 0:
        return
    used_this_turn = true
    var property_name := "%s_dice_current_amount" % Global.dice_type
    Global.set(property_name, Global.get(property_name) + 1)
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit(Global.dice_type, 1)
    Events.temporary_dice_added.emit(Global.dice_type)

func _total_dice_left() -> int:
    var total := 0
    for dice_type in ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]:
        total += int(Global.get("%s_dice_current_amount" % dice_type))
    return total
