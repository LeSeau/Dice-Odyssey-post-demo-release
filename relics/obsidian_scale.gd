extends Relic

# START_OF_TURN, same pattern as Volcanic Rock (relics/volcanic_rock.gd) just on
# turn 2 instead of turn 3, and Evil dice instead of Magma.
func activate_relic(owner: RelicUI) -> void:
    if Global.fight_turn == 1:
        owner.flash()
        Global.evil_dice_current_amount += 1
        Events.dice_roll_reset.emit()
        Events.dice_amount_changed.emit()
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit("evil")
