class_name CounterweightStatus
extends Status

func initialize_status(target: Node) -> void:
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled.bind(target))

func _on_dice_rolled(_dice_type, _roll_value, target: Node) -> void:
    if Global.last_roll % 2 == 0:
        var muscle := preload("res://statuses/muscle.tres").duplicate()
        muscle.stacks = 1
        var status_effect := StatusEffect.new()
        status_effect.status = muscle
        status_effect.execute([target])

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
