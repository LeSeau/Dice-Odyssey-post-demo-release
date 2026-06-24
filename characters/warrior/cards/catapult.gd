extends Card

const LUCKY_STATUS = preload("res://statuses/lucky.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if Global.roll_value <= 2:
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = 6
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
        if not targets.is_empty():
            var tree = targets[0].get_tree()
            var player_targets = tree.get_nodes_in_group("player")
            
            if not player_targets.is_empty():
                var status_effect := StatusEffect.new()
                var lucky := LUCKY_STATUS.duplicate()
                lucky.duration = 1
                status_effect.status = lucky
                status_effect.execute(player_targets)

        Events.dice_roll_reset.emit()
