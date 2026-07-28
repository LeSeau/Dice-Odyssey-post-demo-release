extends Relic
func activate_relic(owner: RelicUI) -> void:
    owner.flash()
    if Global.tutorial_on == false:
        var all_dice = ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]
        var chosen = all_dice[randi() % all_dice.size()]
        Global.set(chosen + "_dice_bonus_amount", Global.get(chosen + "_dice_bonus_amount") + 1)
        print("random dice bonus: " + chosen)
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit(chosen)
