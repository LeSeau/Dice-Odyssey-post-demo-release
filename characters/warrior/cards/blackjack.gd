extends Card

# Exact 21: kill the enemy - bosses included (Julien, 2026-07-20: engineering exactly 21
# against the Leviathan while surviving is earned). Lethal by construction through the
# normal damage path (current HP + block + margin), so block can't save the target and
# death/gold/achievement flows all run as usual. Whiffing at non-21 just discards
# (should_exhaust() only exhausts on a met requirement).


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if targets.is_empty() or not meets_requirement():
        Events.reset_charged_card.emit()
        return
    var target: Node = targets[0]
    var damage_effect := DamageEffect.new()
    # Shows a flat 999 on the popup - "you deleted it", not a literal HP readout
    # (Julien, 2026-07-25). Still floored at lethal in case anything ever has 900+ HP.
    damage_effect.amount = maxi(999, int(target.stats.health) + int(target.stats.block) + 99)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
