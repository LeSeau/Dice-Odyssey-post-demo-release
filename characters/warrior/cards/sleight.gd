extends Card

# Ungated (Julien, 2026-08-24) - base and Sleight+ both carry requirement NONE, so
# meets_requirement() passes trivially on either. They share this one script.

# "Gain Loaded 2 this turn" - the cheap, ungated entry to the Loaded ladder.
#
# Both halves matter: loaded_amount is what dice.gd actually reads on every roll, and
# loaded_expiring marks this slice as turn-scoped so LoadedStatus.apply_status() takes it back
# at the start of the next turn. Granting the badge with stacks = LOADED_AMOUNT keeps the
# counter in step with the global (StatusHandler stacks the delta on an existing badge).
#
# Resets Power like a normal Skill, which naturally makes it a start-of-turn play - exactly
# when you want it, since it pays off over every roll that follows.

const LOADED_STATUS = preload("res://statuses/loaded.tres")
const LOADED_AMOUNT := 2


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Global.loaded_amount += LOADED_AMOUNT
    Global.loaded_expiring += LOADED_AMOUNT
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    var status_effect := StatusEffect.new()
    var loaded := LOADED_STATUS.duplicate()
    loaded.stacks = LOADED_AMOUNT
    status_effect.status = loaded
    status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
