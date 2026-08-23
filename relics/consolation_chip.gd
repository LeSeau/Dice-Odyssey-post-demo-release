extends Relic

# Insurance on the gamble die: a busted Red roll hands the die back instead of just costing
# you the turn. Deliberately refunds the DIE rather than granting Block (Julien, 2026-08-23) -
# a refund keeps you gambling, which is what the Red archetype wants to be doing.

const THRESHOLD := 2


func initialize_relic(owner: RelicUI) -> void:
    Events.red_dice_rolled.connect(_on_red_dice_rolled.bind(owner))
    Events.dice_thrown_landed.connect(_on_dice_thrown_landed.bind(owner))


func _on_red_dice_rolled(owner: RelicUI) -> void:
    if Global.last_roll > THRESHOLD:
        return
    _refund(owner)


func _on_dice_thrown_landed(dice_type: String, value: int, owner: RelicUI) -> void:
    if dice_type != "red" or value > THRESHOLD:
        return
    _refund(owner)


func _refund(owner: RelicUI) -> void:
    owner.flash()
    Global.red_dice_current_amount += 1
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit("red", 1)
    Events.temporary_dice_added.emit("red")


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
    if Events.dice_thrown_landed.is_connected(_on_dice_thrown_landed):
        Events.dice_thrown_landed.disconnect(_on_dice_thrown_landed)
