extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Global.next_roll_modifier+=7
    Events.display_next_roll_modifier.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)

func _on_dice_rolled():
    print("adding dice to damage")
