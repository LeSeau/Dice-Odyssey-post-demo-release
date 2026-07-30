extends Card

const EMANATION_STATUS = preload("res://statuses/status_emanation.tres")


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void: 
    if meets_requirement():
        Global.blue_dice_bonus_amount_fight+=1
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.dice_amount_changed.emit()
        var status_effect := StatusEffect.new()
        var emanation := EMANATION_STATUS.duplicate()
        emanation.duration = 1
        status_effect.status = emanation
        status_effect.execute(targets)
    Events.reset_charged_card.emit()
func _on_dice_rolled():
    print("adding dice to damage")
