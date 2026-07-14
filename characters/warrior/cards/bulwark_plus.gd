extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var players := _get_players(targets)
    # Gain the Block FIRST, then compute damage from the player's Block - the
    # freshly-gained 3 is already counted in the number that gets dealt.
    var block_effect := BlockEffect.new()
    block_effect.amount = 3
    block_effect.sound = sound
    block_effect.execute(players)
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(_get_player_block(targets), Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _get_players(targets: Array[Node]) -> Array[Node]:
    if targets.is_empty():
        return []
    return targets[0].get_tree().get_nodes_in_group("player")

func _get_player_block(targets: Array[Node]) -> int:
    var players := _get_players(targets)
    if players.is_empty():
        return 0
    return players[0].stats.block

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    # No targets available here - Global.player is the only route to live block,
    # so fall back to the static text whenever it isn't set.
    if Global.player == null or not is_instance_valid(Global.player) or Global.player.stats == null:
        return "Gain 3 Block, then deal damage equal to your Block"
    var projected_block := Global.player.stats.block + 3
    var total := apply_target_modifier(modifiers.get_modified_value(projected_block, Modifier.Type.DMG_DEALT), target)
    return "Gain 3 Block, then deal %d damage (equal to your Block)" % total
