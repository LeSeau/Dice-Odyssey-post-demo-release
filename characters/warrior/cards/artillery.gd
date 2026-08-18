extends Card

# "At the start of each turn, throw a Dice of a random type you own at a random enemy."
# The Throw ladder's ENGINE - something flies every single turn without you doing anything,
# and Trebuchet scales all of it. The per-turn behaviour lives in statuses/artillery.gd.

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    status_effect.status = preload("res://statuses/artillery.tres").duplicate()
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
