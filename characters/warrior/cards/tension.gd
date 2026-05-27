extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    Global.starting_power_next_turn = Global.roll_value
    Events.force_end_turn.emit()
    print("starting power next turn:", Global.starting_power_next_turn)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.reset_charged_card.emit()
func _on_dice_rolled():
    print("adding dice to damage")
