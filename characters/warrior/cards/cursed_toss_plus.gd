extends Card

# Cursed Toss+ : TWO thrown Evil Dice instead of one. Own script because the count lives
# in the throw loop. See cursed_toss.gd for the design notes.

const THROW_COUNT := 2


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var target: Node = targets[0]
    var tree := target.get_tree()
    var faces: Array = thrown_faces_for("evil")
    var throws: Array = []
    var stagger := Global.dice_throw_volley_stagger(THROW_COUNT)
    for i in THROW_COUNT:
        var value: int = faces[randi() % faces.size()]
        throws.append({"type": "evil", "value": value, "target": target})
        var die_damage := modifiers.get_modified_value(value, Modifier.Type.DMG_DEALT)
        _land_thrown_die(tree, target, die_damage, Global.DICE_THROW_FLIGHT_TIME + stagger * i, sound, "evil", value)
    Events.dice_thrown.emit(throws, Global.last_played_card_position)
    Events.reset_charged_card.emit()
