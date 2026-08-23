extends Relic

# The first relic that pays off a REQUIREMENT rather than a roll value. Max cards are the
# Low Roll archetype's payoff half, and until now nothing rewarded drafting them.
#
# The bonus itself lives in Global.max_card_damage_bonus and is applied inside
# ModifierHandler.get_modified_value(), so it behaves exactly like a Strength stack: it is
# summed with the other FLAT modifiers before any percentage scaling, and every dynamic
# description picks it up for free (the preview cannot disagree with the damage dealt).

const DAMAGE_BONUS := 3


func initialize_relic(_owner: RelicUI) -> void:
    Global.max_card_damage_bonus = DAMAGE_BONUS


func deactivate_relic(_owner: RelicUI) -> void:
    Global.max_card_damage_bonus = 0
