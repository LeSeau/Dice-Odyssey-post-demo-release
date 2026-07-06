extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    Events.draw_card.emit(3)
    var scout_card = load("res://characters/warrior/cards/card_scout3.tres")
    Events.add_card_to_hand_requested.emit(scout_card)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")
