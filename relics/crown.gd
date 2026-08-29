extends Relic
var _already_triggered := false

func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.battle_started.connect(_on_battle_started.bind(owner))
    _update_counter(owner)


func _on_dice_rolled(dice_type: String, roll_value: int, owner: RelicUI) -> void:
    _update_counter(owner)

    if _already_triggered:
        return

    # >= (not ==) so the threshold can never be skipped over, whatever lands in what order.
    if Global.fight_dice_rolled < 10:
        return

    _already_triggered = true
    owner.flash()

    var active_dice = Global.dice_type
    var dice_amount_variable = active_dice + "_dice_current_amount"

    if dice_amount_variable in Global:
        var current_amount = Global.get(dice_amount_variable)
        Global.set(dice_amount_variable, current_amount + 1)
        Events.dice_charged.emit(active_dice, 1)
        Events.dice_amount_changed.emit()

func _update_counter(owner: RelicUI) -> void:
    owner.counter.text = str(Global.fight_dice_rolled)
    if Global.fight_dice_rolled > 10: 
        owner.counter.text = str(10)
    owner.counter.visible = true

func _on_battle_started(owner: RelicUI) -> void:
    _already_triggered = false
    _update_counter(owner)

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.battle_started.is_connected(_on_battle_started):
        Events.battle_started.disconnect(_on_battle_started)
