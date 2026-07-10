extends Relic

func initialize_relic(owner: RelicUI) -> void:
    Events.red_dice_rolled.connect(_on_red_dice_rolled.bind(owner))

func _on_red_dice_rolled(owner: RelicUI) -> void:
    if Global.last_roll < 5:
        return
    var enemies := owner.get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return
    owner.flash()
    var damage_effect := DamageEffect.new()
    damage_effect.amount = 5
    damage_effect.execute(enemies)

func deactivate_relic(owner: RelicUI) -> void:
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
