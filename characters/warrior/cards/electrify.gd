extends Card

const DEPLETED_STATUS = preload("res://statuses/depleted.tres")


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void: 

    Global.odd_dice_current_amount+=3
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
    Events.charge_dice_animation.emit()
    Events.temporary_dice_added.emit("odd")
    var status_effect := StatusEffect.new()
    var depleted := DEPLETED_STATUS.duplicate()
    depleted.duration = 1
    status_effect.status = depleted
    var player_targets = targets[0].get_tree().get_nodes_in_group("player")
    status_effect.execute(player_targets)
    # The Depleted cost is paid in BLUE, not in the Odd dice this card just handed out
    # (Julien, 2026-07-30): the card is a cross-type trade - a burst of Odd now, one fewer
    # Blue on your next turn - so taxing the same type it just granted would cancel its own
    # point. Reverts the 07-28 switch to odd_dice_bonus_amount.
    Global.blue_dice_bonus_amount -= 1
    Events.reset_charged_card.emit()
func _on_dice_rolled():
    print("adding dice to damage")
