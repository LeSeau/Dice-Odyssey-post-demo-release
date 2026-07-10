extends Relic

func activate_relic(owner: RelicUI) -> void:
    if Global.roll_value <= 0:
        return
    var enemies := owner.get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return
    owner.flash()
    var target = enemies[randi() % enemies.size()]
    var damage_effect := DamageEffect.new()
    damage_effect.amount = Global.roll_value
    damage_effect.execute([target])
