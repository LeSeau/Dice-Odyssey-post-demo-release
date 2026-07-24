class_name HardenedGripStatus
extends Status

func initialize_status(target: Node) -> void:
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled.bind(target))
    # Thrown dice grant their Block too (Julien, 2026-07-23) - per-die opt-in landing
    # signal, so a Pixie Volley or Dice Avalanche drips Block as each die lands.
    if not Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(target))

func _on_dice_thrown_landed(dice_type, value, target: Node) -> void:
    _on_dice_rolled(dice_type, value, target)

func _on_dice_rolled(_dice_type, _roll_value, target: Node) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = 1
    block_effect.execute([target])

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
