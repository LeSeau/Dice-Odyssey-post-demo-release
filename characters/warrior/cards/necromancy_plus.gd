extends Card

# Upgrade of necromancy.gd: same Max 3 gate, one more Evil Dice, keeps the card draw.

const CHARGE_COUNT := 3


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.evil_dice_current_amount += CHARGE_COUNT
    Events.change_current_power.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.draw_card.emit(1)
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit("evil", CHARGE_COUNT)
    Events.temporary_dice_added.emit("evil")
    Events.reset_charged_card.emit()
