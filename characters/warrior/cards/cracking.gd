extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
        print(Global.player.stats.block)
        Events.reset_charged_card.emit()
        var damage_effect := DamageEffect.new()
        var base_damage = Global.player.stats.block
        Global.player.stats.block = 0
        Events.block_reset.emit()
        damage_effect.sound = sound
        damage_effect.execute(targets)
        Events.dice_roll_reset.emit()
