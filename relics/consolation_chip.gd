extends Relic

# Insurance on the gamble die: a busted Red roll hands a die back instead of just costing you
# the turn. Deliberately refunds a DIE rather than granting Block (Julien, 2026-08-23) - a
# refund keeps you gambling, which is what the Red archetype wants to be doing.
#
# Pays a RANDOM type since 2026-08-31 (Julien) rather than replacing the Red die it just ate.
# Two consequences worth knowing: the refund no longer feeds straight back into another Red
# gamble (it is a consolation prize, not a rebate), and it can hand you a type you do not own
# at all - the same "a strange die is a reward in itself" line Stray Die and Voodoo already
# take. CHARGE_TYPES is the full roster on purpose, not the owned subset.

const CHARGE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]
const THRESHOLD := 2


func initialize_relic(owner: RelicUI) -> void:
    Events.red_dice_rolled.connect(_on_red_dice_rolled.bind(owner))


func _on_red_dice_rolled(owner: RelicUI) -> void:
    if Global.last_roll > THRESHOLD:
        return
    _refund(owner)


func _refund(owner: RelicUI) -> void:
    owner.flash()
    var chosen: String = CHARGE_TYPES[randi() % CHARGE_TYPES.size()]
    var amount_field := chosen + "_dice_current_amount"
    Global.set(amount_field, int(Global.get(amount_field)) + 1)
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit(chosen, 1)
    Events.temporary_dice_added.emit(chosen)


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
