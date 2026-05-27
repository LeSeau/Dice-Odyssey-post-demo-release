extends Card

const ECLIPSE_STATUS = preload("res://statuses/eclipse_status.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    Global.no_reset = true
    var status_effect := StatusEffect.new()
    var eclipse := ECLIPSE_STATUS.duplicate()
    status_effect.status = eclipse
    status_effect.execute(targets)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.reset_charged_card.emit()
func _on_dice_rolled():
    print("adding dice to damage")
