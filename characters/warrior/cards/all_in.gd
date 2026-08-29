extends Card

const ALL_DICE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    # By the time this card resolves, the die that carried it is already spent -
    # "remaining" is every other die left in every pool, not just Red anymore.
    # Each remaining die rolls from its OWN face set (thrown_faces_for = infusion-aware,
    # so a Repented Evil can never contribute a 0 and a Bulky Giant rolls 7-12) and that
    # same value drives both the damage bonus and the face shown on the thrown die -
    # what the player sees smash into the enemy is exactly what got added.
    var bonus := 0
    var throws: Array = []
    var target: Node = targets[0] if not targets.is_empty() else null
    for dice_type in ALL_DICE_TYPES:
        var prop := "%s_dice_current_amount" % dice_type
        var remaining: int = Global.get(prop)
        var faces: Array = thrown_faces_for(dice_type)
        for i in remaining:
            var rolled_value: int = faces[randi() % faces.size()]
            bonus += rolled_value
            # "thud": these bashes carry no damage sound of their own (the total lands
            # once at the end), so dice.gd gives each impact a landing clack instead.
            throws.append({"type": dice_type, "value": rolled_value, "target": target, "thud": true})
        Global.set(prop, 0)
    var base_damage: int = Global.roll_value + bonus
    var final_damage := modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    if target != null and is_instance_valid(target) and not throws.is_empty():
        # The consumed dice fly at the target as a sequenced bash volley - the same
        # pipeline as Meteor/Dice Avalanche (dice.gd's Events.dice_thrown handler), so
        # each die rises, locks its face and slams in turn. The whole total lands as ONE
        # hit synced to the FINAL die's impact. Deliberately NOT per-die damage: that
        # would multiply Strength by the dice count.
        #
        # This lump IS the card's own damage, so unlike a thrown die's raw face value it
        # still takes Strength - keep it that way. The spent dice themselves report nothing
        # (they never did), which is now simply the same rule every throw follows.
        if Global.berserker_boost_active and target is Enemy:
            # The Berserker ×1.5 flag is cleared by card.gd right after play - the hit
            # now lands seconds later, so bake the boost into the number up front.
            final_damage = ceili(final_damage * 1.5)
        Events.dice_thrown.emit(throws, Global.last_played_card_position)
        var n := throws.size()
        var land_delay: float = Global.DICE_THROW_FLIGHT_TIME \
                + Global.dice_throw_volley_stagger(n) * (n - 1)
        var timer := target.get_tree().create_timer(land_delay, false)
        timer.timeout.connect(_on_all_in_landed.bind(target.get_tree(), target, final_damage))
    else:
        # No dice left (or no valid target): just the Power hit, immediately - nothing
        # to sequence. The still-active Berserker flag applies inside DamageEffect here,
        # so no pre-multiply (that would double it).
        var damage_effect := DamageEffect.new()
        damage_effect.amount = final_damage
        damage_effect.sound = sound
        if target != null and is_instance_valid(target):
            damage_effect.popup_origin = thrown_impact_pos(target)
        damage_effect.execute(targets)
    Events.dice_amount_changed.emit()
    Events.dice_roll_reset.emit()


# The lump hit, landing in sync with the volley's final die. Mirrors
# Card._on_thrown_die_landed's retargeting (target died mid-flight -> bounce to a random
# living enemy; fight over -> fizzle) but deliberately does NOT call
# Global.report_thrown_die_landed - see the note in apply_effects.
func _on_all_in_landed(tree: SceneTree, target: Node, damage: int) -> void:
    var final_target := target
    if final_target == null or not is_instance_valid(final_target):
        var alive := tree.get_nodes_in_group("enemies")
        if alive.is_empty():
            return
        final_target = alive[randi() % alive.size()]
    var damage_effect := DamageEffect.new()
    damage_effect.amount = damage
    damage_effect.sound = sound
    damage_effect.popup_origin = thrown_impact_pos(final_target)
    damage_effect.execute([final_target])


func _total_remaining() -> int:
    var total := 0
    for dice_type in ALL_DICE_TYPES:
        total += int(Global.get("%s_dice_current_amount" % dice_type))
    return total


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    return "Deal X damage. Spend all your remaining Dice: each adds its roll\n(%d Dice remaining)" % _total_remaining()
