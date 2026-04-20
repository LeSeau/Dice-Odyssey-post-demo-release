extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.draw_card.emit(3)
    if Global.roll_value % 2 == 0:
        Events.draw_card.emit(1)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
    
func _on_dice_rolled():
    print("adding dice to damage")
