extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    var scout_card = load("res://characters/warrior/cards/card_scout3.tres")
    Events.add_card_to_hand_requested.emit(scout_card)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

        
