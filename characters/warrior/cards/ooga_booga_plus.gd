extends Card

# OOGA BOOGA. He does not understand requirements. When a Red roll misses the one printed on
# the card you socketed, he smashes the board anyway.
#
# The multiplier lives in a const rather than on the .tres because Card has no payload field
# for a plain number - same reason Ringer+ needed its own script. KEEP IN SYNC with
# ooga_booga_plus.gd (3), both .tres descriptions, and both status tooltips.
const MULT := 3

const OOGA_STATUS = preload("res://statuses/status_ooga_booga_plus.tres")


func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
    # No value gate. Requirement.RED is satisfied by ANY Red roll, which is also the thing that
    # stops this card from ever triggering itself. The cost is the Red socket, the Red roll and
    # the banked Power the reset below spends.
    #
    # maxi() rather than += : this is a multiplier on the whole payout, not a flat bonus like
    # Trebuchet's, so letting two copies stack to X4 compounds with Berserk and the Berserker
    # infusion into far more than a second draft of the same card should buy. The trade is that
    # a second copy is a dead play. One word to flip if that reads worse in practice.
    Global.red_whiff_damage_mult = maxi(Global.red_whiff_damage_mult, MULT)
    # Targeted at Global.player rather than the passed-in `targets`: that array is only filled
    # by hovering an enemy Area2D, and a card socketed onto the Red die never has to cross one,
    # so relying on it would sometimes drop the badge while the effect still installed.
    var status_effect := StatusEffect.new()
    var ooga: Status = OOGA_STATUS.duplicate()
    status_effect.status = ooga
    status_effect.sound = sound
    status_effect.execute([Global.player])
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
