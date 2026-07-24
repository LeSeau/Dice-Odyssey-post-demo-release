extends Relic

func initialize_relic(owner: RelicUI) -> void:
    Events.red_dice_rolled.connect(_on_red_dice_rolled.bind(owner))
    # A THROWN Red Dice landing on 5-6 pays out too (Julien, 2026-07-23) - only Dice
    # Avalanche's red die and Fastball played on red can produce one today, so this stays
    # a rare treat rather than a build-around.
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))

func _on_red_dice_rolled(owner: RelicUI) -> void:
    if Global.last_roll < 5:
        return
    _payout(owner)

func _on_dice_thrown_landed(dice_type: String, value: int, owner: RelicUI) -> void:
    if dice_type != "red" or value < 5:
        return
    _payout(owner)

func _payout(owner: RelicUI) -> void:
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
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
