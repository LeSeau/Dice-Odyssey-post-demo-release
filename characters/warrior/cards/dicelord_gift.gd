extends Card

# Blessing (Odd requirement): Charge a random Dice at the start of each turn for the rest
# of the combat (DicelordGiftStatus). The `or Global.blessing_cast_any_roll` term is the
# Prayer Beads rule - every Blessing's cast condition must include it.

const GIFT_STATUS = preload("res://statuses/status_dicelord_gift.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if meets_requirement() or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        status_effect.status = GIFT_STATUS.duplicate()
        status_effect.sound = sound
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
