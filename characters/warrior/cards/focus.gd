extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    Global.next_guaranteed_roll = 6
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.next_roll_determined.emit()

func _on_dice_rolled():
    print("adding dice to damage")
