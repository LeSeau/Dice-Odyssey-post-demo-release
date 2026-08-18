extends Card

# The rainbow payoff (Julien's idea, 2026-08-16): nothing else in the pool reads dice-type
# DIVERSITY. Self-balancing by the core rules - switching type resets your Power, so going
# rainbow costs you the chain, and the cost is already paid by the mechanic that exists.
# It also makes the dice SHOP part of the build: every extra type you own raises the ceiling.

const DAMAGE_PER_TYPE := 4


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage := modifiers.get_modified_value(_damage(), Modifier.Type.DMG_DEALT)
    if damage > 0 and not targets.is_empty():
        var damage_effect := DamageEffect.new()
        damage_effect.amount = damage
        damage_effect.sound = sound
        damage_effect.execute(targets)
    Events.dice_roll_reset.emit()


func _damage() -> int:
    return Global.dice_types_rolled_this_turn.size() * DAMAGE_PER_TYPE


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var base := "For each Dice type you have rolled this turn, deal %d damage to ALL enemies" \
        % DAMAGE_PER_TYPE
    if is_inked():
        return base
    var total := apply_target_modifier(
        modifiers.get_modified_value(_damage(), Modifier.Type.DMG_DEALT), target)
    return "%s (%d)" % [base, total]
