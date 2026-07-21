extends Card

# Blackjack+ : Exact 21 kills the enemy AND grants 21 Gold (base blackjack.gd, no gold).
# Gold is granted regardless of whether the kill "matters" (already-lethal edge) - the
# reward is for hitting 21, same as the kill.


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if targets.is_empty() or not meets_requirement():
        Events.reset_charged_card.emit()
        return
    var target: Node = targets[0]
    var damage_effect := DamageEffect.new()
    damage_effect.amount = int(target.stats.health) + int(target.stats.block) + 99
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Global.gold += 21
    Events.gold_changed.emit()
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
