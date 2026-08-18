extends Relic



func activate_relic(owner: RelicUI) -> void:
    var player := owner.get_tree().get_first_node_in_group("player") as Player

    if Global.fight_turn == 2:
        owner.flash()
        Global.magma_dice_current_amount+=2
        Events.dice_roll_reset.emit()
        Events.dice_amount_changed.emit()
        Events.dice_charged.emit("magma", 2)
        Events.temporary_dice_added.emit("magma")
    
