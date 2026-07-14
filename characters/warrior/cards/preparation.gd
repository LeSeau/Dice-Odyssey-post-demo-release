extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    Events.draw_card.emit(2)
    Global.next_roll_modifier += 2
    Events.display_next_roll_modifier.emit()
    # load() is still ResourceLoader-cached by path - duplicate so a repeat trigger never
    # hands out the SAME Card object twice (see calculations.gd for the full rationale).
    var scout_card = load("res://characters/warrior/cards/card_scout2.tres").duplicate()
    Events.add_card_to_hand_requested.emit(scout_card)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")
