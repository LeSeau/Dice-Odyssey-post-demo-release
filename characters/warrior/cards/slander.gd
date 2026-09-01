extends Card

# The Slanderer plants this in your DISCARD pile. It is the gentlest junk shape: never
# unplayable, never harmful, it just occupies a draw until you spend the tempo to bin it.
#
# Deliberately does NOTHING in apply_effects - the cost is the card slot and the click, not an
# effect. It exhausts (card.tres), so playing it removes it from the fight for good.
#
# Celestial (can_play_without_dice) on purpose: a dead card you cannot get rid of without
# first rolling would be a trap rather than a tax. It emits no dice_roll_reset, so it also
# honours the standing rule that no Celestial card resets your Power.
#
# NOT in the draftable pool - it only ever arrives by injection.
func apply_effects(_targets: Array[Node], _modifiers: ModifierHandler) -> void:
    pass
