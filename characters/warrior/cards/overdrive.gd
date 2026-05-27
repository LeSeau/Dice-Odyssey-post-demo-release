extends Card

const DEPLETED_STATUS = preload("res://statuses/depleted.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value < 10 :
        var status_effect := StatusEffect.new()
        var depleted := DEPLETED_STATUS.duplicate()
        depleted.duration = 1
        status_effect.status = depleted
        var player_targets = targets[0].get_tree().get_nodes_in_group("player")
        status_effect.execute(player_targets)

        Global.blue_dice_bonus_amount -= 1
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value*2
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
