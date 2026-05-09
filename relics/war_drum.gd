extends Relic

var triggerable = true

func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.change_current_power.connect(_on_change_current_power.bind(owner))

func _deal_aoe_damage(owner: RelicUI) -> void:
    owner.flash()
    var enemies = owner.get_tree().get_nodes_in_group("enemies")
    if enemies.size() == 0:
        return
    var dmg = DamageEffect.new()
    dmg.amount = 5
    dmg.execute(enemies)
    triggerable = false

func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:
    if Global.roll_value > 9 and triggerable:
        _deal_aoe_damage(owner)
    elif Global.roll_value < 5:
        triggerable = true

func _on_change_current_power(owner: RelicUI) -> void:
    if Global.roll_value > 9 and triggerable:
        _deal_aoe_damage(owner)
    elif Global.roll_value < 5:
        triggerable = true

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.change_current_power.is_connected(_on_change_current_power):
        Events.change_current_power.disconnect(_on_change_current_power)
