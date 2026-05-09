extends Card

const WEAK_STATUS = preload("res://statuses/weak.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    print("Reinforce applied")
    Events.reset_charged_card.emit()
    Global.roll_value+=4
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    var status_effect := StatusEffect.new()
    var weak := WEAK_STATUS.duplicate()
    weak.stacks = 1
    status_effect.status = weak
    status_effect.execute(targets)
    support_effect.sound = sound
    support_effect.execute(targets)
