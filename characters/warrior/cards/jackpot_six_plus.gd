extends Card

# Jackpot+ drops the Exhaust (Julien, 2026-08-20). The tally it reads is fight-long and never
# resets, so being able to play it twice late in a fight is the entire upgrade - the second
# copy hits for at least as much as the first.

const DAMAGE_PER_SIX := 6


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
    return Global.sixes_rolled_this_fight * DAMAGE_PER_SIX


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    var base := "Deal %d damage for every 6 you rolled this fight" % DAMAGE_PER_SIX
    if is_inked():
        return base
    var total := apply_target_modifier(
        modifiers.get_modified_value(_damage(), Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage for every 6 you rolled this fight (%d)" % [DAMAGE_PER_SIX, total]
