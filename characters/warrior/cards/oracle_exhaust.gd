extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    Events.scout_effect.emit(3)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)

func _on_dice_rolled():
    print("adding dice to damage")
