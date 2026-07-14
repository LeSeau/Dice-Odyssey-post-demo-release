# Act-2 dice infusions - the "ancient relic"-style major power spike offered right after
# the act-1 boss (see scenes/dice_infusion/dice_infusion.gd for the choice screen). Each
# dice TYPE can define one infusion that permanently transforms every die of that type
# for the rest of the run. The screen rolls 2 random owned types that have an entry here
# (roll_candidates()); the pick is stored in Global.dice_infusions ({"blue": "arcane"})
# and saved/restored with the run by run.gd.
#
# One infusion per type for now (Julien wants several per type eventually). Consumers:
# - scenes/dice_infusion/dice_infusion.gd  (the post-boss choice screen)
# - scenes/dices/dice.gd                   (Arcane natural-6 draw trigger + infused aura recolor)
# - custom_resources/card.gd + effects/damage_effect.gd (Berserker socketed-card +50% damage)
# - custom_resources/dice_palette.gd       (infused accent/outline -> power number, orbs,
#                                           particles, popups, card glow all recolor at once)
# - scenes/ui/dice_tooltip.gd              (renamed tooltip + infusion effect line)
class_name DiceInfusions
extends RefCounted

const INFUSIONS := {
    "blue": {
        "id": "arcane",
        "name": "Arcane Dice",
        "description": "Every time you roll a 6, draw 2 cards.",
        # Bright identity color (power number, orbs, labels): a clearly "arcane" violet,
        # kept away from Evil's fuchsia (E14FE1). First-pass values, tune freely.
        "accent": Color("9A66FF"),
        "outline": Color("22084D"),
        # Aura shader recolor (magic_color / accent_color on the duplicated material,
        # see dice.gd::_resolve_aura_material).
        "aura_magic": Color(0.55, 0.35, 1.0, 0.9),
        "aura_accent": Color(0.33, 0.12, 0.9, 0.83),
    },
    "red": {
        "id": "berserker",
        "name": "Berserker Dice",
        "description": "Cards played on your Red Dice deal 50% more damage.",
        "accent": Color("FF5C33"),
        "outline": Color("4D0900"),
        "aura_magic": Color(1.0, 0.32, 0.14, 0.95),
        "aura_accent": Color(1.0, 0.62, 0.3, 0.85),
    },
}


static func has_infusion_for(dice_type: String) -> bool:
    return INFUSIONS.has(dice_type)


static func get_info(dice_type: String) -> Dictionary:
    return INFUSIONS.get(dice_type, {})


# The random different owned dice types offered on the infusion screen. Only types that
# actually have an infusion designed qualify (today: blue & red, which the player always
# owns - the pool widens automatically as more entries are added to INFUSIONS above).
static func roll_candidates(count: int = 2) -> Array[String]:
    var owned: Array[String] = []
    for dice_type: String in INFUSIONS.keys():
        if Global.is_dice_infused(dice_type):
            continue
        var max_amount: int = Global.get(dice_type + "_dice_max_amount")
        if max_amount > 0:
            owned.append(dice_type)
    owned.shuffle()
    return owned.slice(0, count)
