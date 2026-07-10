extends Card

const ALL_DICE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    # By the time this card resolves, the die that carried it is already spent -
    # "remaining" is every other die left in every pool, not just Red anymore.
    var bonus := 0
    for dice_type in ALL_DICE_TYPES:
        var prop := "%s_dice_current_amount" % dice_type
        var remaining: int = Global.get(prop)
        for i in remaining:
            bonus += randi_range(1, 6)
        Global.set(prop, 0)
    var damage_effect := DamageEffect.new()
    var base_damage: int = Global.roll_value + bonus
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_amount_changed.emit()
    Events.dice_roll_reset.emit()

func _total_remaining() -> int:
    var total := 0
    for dice_type in ALL_DICE_TYPES:
        total += int(Global.get("%s_dice_current_amount" % dice_type))
    return total

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    return "Deal X damage. Spend all your remaining Dice: each adds its own roll\n(%d Dice remaining)" % _total_remaining()
