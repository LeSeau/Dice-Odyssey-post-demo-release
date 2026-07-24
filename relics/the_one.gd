extends Relic


func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    # The fight's first 1 can come from a thrown die too (Julien, 2026-07-23).
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))
    print("initializing the one relic")


func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:
    if Global.last_roll != 1:
        return
    _grant_bonus_die(owner)


func _on_dice_thrown_landed(_dice_type: String, value: int, owner: RelicUI) -> void:
    if value != 1:
        return
    _grant_bonus_die(owner)


func _grant_bonus_die(owner: RelicUI) -> void:
    if Global.has_rolled_1_this_fight:
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
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
