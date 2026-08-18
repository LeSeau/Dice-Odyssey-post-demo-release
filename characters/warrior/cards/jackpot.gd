extends Card

# The sixes CONCLUDER - the rare a sixes run becomes about. Counts natural 6s only (see
# dice.gd, where Global.sixes_rolled_this_fight is incremented next to has_rolled_6_this_turn),
# so it can't be inflated by Boost or Loaded.
#
# The cross-link that makes it exciting: the Evil die is 75% sixes, so buying Evil stops being
# a gamble stat and becomes fuel for this card.

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
    var base := "Deal %d damage for every 6 you rolled this fight. Exhaust" % DAMAGE_PER_SIX
    if is_inked():
        return base
    var total := apply_target_modifier(
        modifiers.get_modified_value(_damage(), Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage for every 6 you rolled this fight (%d). Exhaust" % [DAMAGE_PER_SIX, total]
