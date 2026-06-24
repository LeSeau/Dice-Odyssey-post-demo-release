class_name OpeningGambitStatus
extends Status

var triggered_this_turn := true

func initialize_status(_target: Node) -> void:
    triggered_this_turn = true
    if not Events.player_turn_started.is_connected(_on_turn_started):
        Events.player_turn_started.connect(_on_turn_started)
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)

func _on_turn_started() -> void:
    triggered_this_turn = false

func _on_dice_rolled(_dice_type, _roll_value) -> void:
    if not triggered_this_turn:
        triggered_this_turn = true
        Global.roll_value += Global.last_roll
        Events.change_current_power.emit()

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
