extends Card

# Sleight+: same Loaded 2, but Celestial and it does NOT reset your Power.
#
# Split off from sleight.gd (2026-08-24) for that one omission. Base Sleight still resets like
# a normal Skill; only the upgrade keeps your chain. That pairing is deliberate - the base is a
# start-of-turn play you build around, the upgrade can be dropped in mid-chain for free.
#
# The no-reset half is not optional once the card is Celestial: a Celestial card is meant to be
# playable when you have nothing left, and a reset there would wipe banked Power to grant a
# buff that only helps rolls you can no longer make. Same rule the 2026-07-21 audit enforced on
# Adrenaline / Occultism / Supplication - no Celestial card resets Power.
#
# ⚠️ The Loaded bookkeeping below is duplicated from sleight.gd on purpose (the .tres pair
# needs two scripts to diverge). Any change to how Loaded is granted must be made in BOTH.

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
    Events.reset_charged_card.emit()
