extends Card

# Celestial coin-flip comedy: hurls a conjured Evil Dice (faces 6/6/6/0) for double its
# roll - 12 damage, or a fat "0" popup when the crack comes up (the flight visual shows
# the cracked face and plays the crack sound). SUPPORT flag: never resets your Power.
# Strength applies to the die's damage like any other hit (Julien, 2026-07-21) - on the
# crack (0), that means the popup shows your Strength alone rather than a literal 0,
# same as any other 0-base hit in the game. Not a new exception, just consistent.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var faces: Array = thrown_faces_for("evil")
    var value: int = faces[randi() % faces.size()]
    var target: Node = targets[0]
    Events.dice_thrown.emit([{"type": "evil", "value": value, "target": target}], Global.last_played_card_position)
    var die_damage := modifiers.get_modified_value(value * 2, Modifier.Type.DMG_DEALT)
    _land_thrown_die(target.get_tree(), target, die_damage, Global.DICE_THROW_FLIGHT_TIME, sound, "evil", value)
    Events.reset_charged_card.emit()
