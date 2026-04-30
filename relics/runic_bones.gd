class_name RunicBones
extends Relic

func initialize_relic(owner: RelicUI) -> void:
    Events.charge_dice_animation.connect(_on_charge_dice.bind(owner))

func _on_charge_dice(owner: RelicUI) -> void:
    if Global.charged_dice_this_turn:
        return
    Global.charged_dice_this_turn = true
    owner.flash()
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if not player:
        return
    var block_effect := BlockEffect.new()
    block_effect.amount = 4
    block_effect.execute([player])

func deactivate_relic(owner: RelicUI) -> void:
    if Events.charge_dice_animation.is_connected(_on_charge_dice):
        Events.charge_dice_animation.disconnect(_on_charge_dice)
