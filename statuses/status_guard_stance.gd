class_name GuardStanceStatus
extends Status

var triggered_this_turn := false

func initialize_status(target: Node) -> void:
    if not Events.player_turn_started.is_connected(_on_turn_started):
        Events.player_turn_started.connect(_on_turn_started)
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled.bind(target))

func _on_turn_started() -> void:
    triggered_this_turn = false

func _on_dice_rolled(_dice_type, _roll_value, target: Node) -> void:
    if not triggered_this_turn:
        triggered_this_turn = true
        var block_effect := BlockEffect.new()
        block_effect.amount = Global.last_roll
        block_effect.execute([target])

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
