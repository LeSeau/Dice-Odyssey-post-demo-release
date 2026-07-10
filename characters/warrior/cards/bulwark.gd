extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(_get_player_block(targets), Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _get_player_block(targets: Array[Node]) -> int:
    if targets.is_empty():
        return 0
    var players := targets[0].get_tree().get_nodes_in_group("player")
    if players.is_empty():
        return 0
    return players[0].stats.block

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    # No targets available here - Global.player is the only route to live block,
    # so fall back to the static text whenever it isn't set.
    if Global.player == null or not is_instance_valid(Global.player) or Global.player.stats == null:
        return "Deal damage equal to your Block"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.player.stats.block, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage (equal to your Block)" % total
