extends Card

const LUCKY_STATUS = preload("res://statuses/lucky.tres")


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value == 6: 
        Global.giant_dice_current_amount+=1
        Events.change_current_power.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit("giant")
        var status_effect := StatusEffect.new()
        var lucky := LUCKY_STATUS.duplicate()
        lucky.duration = 1
        status_effect.status = lucky
        status_effect.execute(targets)
        Events.card_type_played.emit("exact")

func _on_dice_rolled():
    print("adding dice to damage")
