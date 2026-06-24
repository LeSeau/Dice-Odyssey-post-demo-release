extends Card

const COGWORK_STATUS = preload("res://statuses/status_cogwork.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value == 6:
        Global.mech_dice_bonus_amount_fight += 1
        if not Global.dice_inventory.has("mech"):
            Global.dice_inventory.append("mech")
        Events.temporary_dice_added.emit("mech")
        var status_effect := StatusEffect.new()
        var cogwork := COGWORK_STATUS.duplicate()
        status_effect.status = cogwork
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
