class_name HardenedGripStatus
extends Status

func initialize_status(target: Node) -> void:
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled.bind(target))


func _on_dice_rolled(_dice_type, _roll_value, target: Node) -> void:
    var block_effect := BlockEffect.new()
    # stacks = copies played (the .tres ships 1, absorb_copy adds each extra Die Hard / Die Hard+).
    block_effect.amount = maxi(stacks, 1)
    block_effect.execute([target])


func absorb_copy(other: Status) -> bool:
    stacks += other.stacks
    return true


func get_tooltip() -> String:
    return "Gain %d Block every time you roll a Dice" % maxi(stacks, 1)

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
