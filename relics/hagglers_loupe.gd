extends Relic

# Buying dice is the game's real power curve, so a discount on them is a discount on the
# whole run. Applied as a percentage inside Global.current_dice_price(), AFTER the purchase
# escalation - so it stays worth the same proportion late, when dice are expensive, instead
# of decaying into a rounding error.
#
# Works outside combat because relics are only ever deactivated when the relic itself is
# removed: the RelicHandler lives in run.tscn and survives every scene change.

const DISCOUNT := 0.15


func initialize_relic(_owner: RelicUI) -> void:
    Global.dice_price_discount = DISCOUNT
    # The map's "you can afford a die" badge and the shop both compare gold against a cached
    # cheapest price, so it has to be re-derived or the discount would not show until the
    # next event that happens to change a price.
    Global.refresh_cheapest_dice_price()
    Events.dice_price_changed.emit()


func deactivate_relic(_owner: RelicUI) -> void:
    Global.dice_price_discount = 0.0
    Global.refresh_cheapest_dice_price()
    Events.dice_price_changed.emit()
