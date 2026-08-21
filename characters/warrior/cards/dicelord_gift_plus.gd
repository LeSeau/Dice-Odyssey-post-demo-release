extends Card

# Dicelord's Gift+: two random dice a turn instead of one. The count lives on
# status_dicelord_gift_plus.tres::stacks, which shares statuses/status_dicelord_gift.gd with
# the base version.

const GIFT_STATUS = preload("res://statuses/status_dicelord_gift_plus.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if meets_requirement() or Global.blessing_cast_any_roll:
        var status_effect := StatusEffect.new()
        status_effect.status = GIFT_STATUS.duplicate()
        status_effect.sound = sound
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
