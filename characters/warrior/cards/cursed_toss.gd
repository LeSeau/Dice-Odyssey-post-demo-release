extends Card

# A free throw: hurls 1 conjured Golem Dice (2/4/6/8) at the target, dealing its
# own roll (Julien, 2026-07-25: "basically Slash but funnier" - Slash was cut for it).
# Celestial + SUPPORT flag: playable at zero resources and it never resets your Power, so
# the dice are pure bonus damage on top of whatever you had banked. Strength applies to
# each die like any other hit. Each die lands on its own beat via the shared volley
# stagger, so you read "6... 3" as two separate smacks rather than one lump.

const THROW_COUNT := 1


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty():
        Events.reset_charged_card.emit()
        return
    var target: Node = targets[0]
    var tree := target.get_tree()
    var faces: Array = thrown_faces_for("even")
    var throws: Array = []
    var stagger := Global.dice_throw_volley_stagger(THROW_COUNT)
    for i in THROW_COUNT:
        var value: int = faces[randi() % faces.size()]
        throws.append({"type": "even", "value": value, "target": target})
        var die_damage := modifiers.get_modified_value(value, Modifier.Type.DMG_DEALT)
        _land_thrown_die(tree, target, die_damage, Global.DICE_THROW_FLIGHT_TIME + stagger * i, sound, "even", value)
    Events.dice_thrown.emit(throws, Global.last_played_card_position)
    Events.reset_charged_card.emit()
