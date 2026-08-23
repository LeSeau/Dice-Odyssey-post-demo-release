extends Relic

# A guest die every fight, always of a type you do NOT own - the relic exists to sell the
# "discovering new dice is the fun" agenda, so handing you a tenth Blue would defeat it.
# Rolls a fresh type each combat, so it also teaches the exotic types by letting you hold one.


func activate_relic(owner: RelicUI) -> void:
    var unowned: Array[String] = []
    for candidate: String in Global.DICE_TYPE_ORDER:
        # max_amount, not current: the question is what you OWN, and current_amount is
        # whatever this turn's refill happens to have left in the pool.
        var owned: int = Global.get(candidate + "_dice_max_amount")
        if owned <= 0:
            unowned.append(candidate)
    if unowned.is_empty():
        return  # a full collection: nothing left to be a stranger

    var chosen: String = unowned[randi() % unowned.size()]
    owner.flash()
    # bonus_amount, NOT current_amount. START_OF_COMBAT relics finish activating before
    # player_handler starts turn 1, and that refill OVERWRITES current_amount with
    # max + bonus - a direct bump would be wiped before the player ever saw it. The refill
    # adds bonus and then zeroes it, so this lands exactly once, on turn 1. Same mechanism
    # Dice Bag uses for its extra Blue die.
    var bonus_field := chosen + "_dice_bonus_amount"
    Global.set(bonus_field, Global.get(bonus_field) + 1)
    Events.dice_amount_changed.emit()
    Events.dice_charged.emit(chosen, 1)
    Events.temporary_dice_added.emit(chosen)
