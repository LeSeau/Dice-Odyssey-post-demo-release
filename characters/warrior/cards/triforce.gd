extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value % 3 == 0: 
        Events.dice_rolled.emit()
        Global.roll_value=3
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.draw_card.emit(3)
        var block_effect := BlockEffect.new()
        block_effect.amount = 3
        block_effect.execute(targets)

func _on_dice_rolled():
    print("adding dice to damage")
