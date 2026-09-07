extends Relic

# GRANTS a die, it does not CHARGE one (Julien, 2026-09-07). The distinction is the whole
# point: dice_charged is the "a card/effect just charged you" event, and Runic Bones pays
# out on it. A relic that simply opens the fight with an extra die must not feed those
# payoffs, or every start-of-combat die relic quietly becomes a Runic Bones trigger.
#
# It is also an ordering fix. START_OF_COMBAT relics run BEFORE player_handler.start_battle()
# (battle.gd only calls it on relics_activated, at the END of the cascade), so a charge here
# reached Runic Bones -> draw_card while `character` was still null and crashed the fight.
#
# dice_amount_changed already refreshes all nine slot labels and temporary_dice_added makes
# the slot appear and resizes the panel, so the die shows up exactly as before. Only the
# charge ceremony (flying icons, panel ripple, the big die's gust) is gone, which is what
# "just give the dice" means.
func activate_relic(owner: RelicUI) -> void:
    owner.flash()
    if Global.tutorial_on == false:
        var all_dice = ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]
        var chosen = all_dice[randi() % all_dice.size()]
        Global.set(chosen + "_dice_bonus_amount", Global.get(chosen + "_dice_bonus_amount") + 1)
        Events.dice_amount_changed.emit()
        Events.temporary_dice_added.emit(chosen)
