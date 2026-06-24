extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Global.roll_value-=1
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var block_effect := BlockEffect.new()
    block_effect.amount = 5
    block_effect.sound = sound
    block_effect.execute(targets)

func _on_dice_rolled():
    print("adding dice to damage")
