extends Relic


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    print("initializing the one relic")


func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:
    if Global.last_roll != 1 or Global.has_rolled_1_this_fight:
        return
    

    owner.flash()
    
    var active_dice = Global.dice_type
    var dice_amount_variable = active_dice + "_dice_current_amount"
    
    if dice_amount_variable in Global:
        var current_amount = Global.get(dice_amount_variable)
        Global.set(dice_amount_variable, current_amount + 1)
        Events.change_current_power.emit()
        Events.charge_dice_animation.emit()
        Events.dice_amount_changed.emit()
        Global.has_rolled_1_this_fight = true

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
