extends Card

const ALL_DICE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    var active: String = Global.dice_type
    var total_moved := 0
    for dice_type in ALL_DICE_TYPES:
        if dice_type == active:
            continue
        var prop := "%s_dice_current_amount" % dice_type
        total_moved += int(Global.get(prop))
        Global.set(prop, 0)
    if total_moved > 0:
        var active_prop := "%s_dice_current_amount" % active
        Global.set(active_prop, int(Global.get(active_prop)) + total_moved)
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit(active, total_moved)
    Events.temporary_dice_added.emit(active)
    Events.reset_charged_card.emit()
