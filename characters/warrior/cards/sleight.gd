extends Card

# Ungated (Julien, 2026-08-24) - requirement NONE, so meets_requirement() passes trivially.
#
# Sleight+ is a separate script (sleight_plus.gd): it is Celestial and does NOT reset Power.
# This base version DOES reset, like a normal Skill - that reset is the whole cost of the
# card, and dropping it is the upgrade. ⚠️ The Surge bookkeeping below is mirrored there;
# change both together.

# "Gain Surge 2 this turn" - the cheap, ungated entry to the Surge ladder.
#
# Both halves matter: surge_amount is what dice.gd actually reads on every roll, and
# surge_expiring marks this slice as turn-scoped so SurgeStatus.apply_status() takes it back
# at the start of the next turn. Granting the badge with stacks = SURGE_AMOUNT keeps the
# counter in step with the global (StatusHandler stacks the delta on an existing badge).
#
# Resets Power like a normal Skill, which naturally makes it a start-of-turn play - exactly
# when you want it, since it pays off over every roll that follows.

const SURGE_STATUS = preload("res://statuses/surge.tres")
const SURGE_AMOUNT := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.surge_amount += SURGE_AMOUNT
    Global.surge_expiring += SURGE_AMOUNT
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    var surge := SURGE_STATUS.duplicate()
    surge.stacks = SURGE_AMOUNT
    status_effect.status = surge
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
