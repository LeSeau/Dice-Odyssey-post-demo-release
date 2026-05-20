extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var scout_amount = 3 
    Events.scout_effect.emit(scout_amount)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)

func _on_dice_rolled():
    print("adding dice to damage")
