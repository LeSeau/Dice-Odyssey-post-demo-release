extends Card

# Cursed Toss+ : thrown Evil Dice deals TRIPLE its roll (base is double). See cursed_toss.gd.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var faces: Array = DICE_FACE_VALUES["evil"]
    var value: int = faces[randi() % faces.size()]
    var target: Node = targets[0]
    Events.dice_thrown.emit([{"type": "evil", "value": value, "target": target}], Global.last_played_card_position)
    var die_damage := modifiers.get_modified_value(value * 3, Modifier.Type.DMG_DEALT)
    _land_thrown_die(target.get_tree(), target, die_damage, Global.DICE_THROW_FLIGHT_TIME, sound)
    Events.reset_charged_card.emit()
