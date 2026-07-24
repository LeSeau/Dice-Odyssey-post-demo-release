extends Card

# Max 4 gate caps the volley: X = your Power = how many Pixie Dice fly, each at a random
# enemy for double its roll (d3, so 2/4/6 per die). Above 4 Power the card whiffs like
# any failed requirement.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty() or not has_active_roll() or not meets_requirement():
        Events.reset_charged_card.emit()
        return
    var count := int(Global.roll_value)
    if count <= 0:
        Events.reset_charged_card.emit()
        return
    var tree := targets[0].get_tree()
    var faces: Array = thrown_faces_for("green")
    var throws: Array = []
    # Shared volley stagger keeps each pixie's hit landing exactly on its die's slam.
    var stagger := Global.dice_throw_volley_stagger(count)
    for i in count:
        var value: int = faces[randi() % faces.size()]
        var target: Node = targets[randi() % targets.size()]
        throws.append({"type": "green", "value": value, "target": target})
        var die_damage := modifiers.get_modified_value(value * 2, Modifier.Type.DMG_DEALT)
        _land_thrown_die(tree, target, die_damage, Global.DICE_THROW_FLIGHT_TIME + stagger * i, sound, "green", value)
    Events.dice_thrown.emit(throws, Global.last_played_card_position)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Throw ? Pixie Dice at random enemies. Each deals double its roll"
    if not has_active_roll() or not meets_requirement():
        return "Throw X Pixie Dice at random enemies. Each deals double its roll"
    return "Throw %d Pixie Dice at random enemies. Each deals double its roll" % int(Global.roll_value)
