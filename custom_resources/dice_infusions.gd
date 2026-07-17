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
        "description": "Every time you roll a 6, deal 5 damage to all enemies.",
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
    "evil": {
        "id": "repented",
        "name": "Repented Dice",
        "description": "Remove the corrupted face. Evil Dice faces are now 6, 6, 6.",
        # roll_values overrides the die's value/face set (see roll_values_override()). Evil
        # was [0, 6, 6, 6]; repentance drops the crack.
        "roll_values": [6, 6, 6],
        "accent": Color("FFDE7A"),  # holy/redeemed gold
        "outline": Color("5A4410"),
        "aura_magic": Color(1.0, 0.85, 0.45, 0.9),
        "aura_accent": Color(0.85, 0.6, 0.2, 0.83),
    },
    "giant": {
        "id": "bulky",
        "name": "Bulky Dice",
        "description": "Remove faces 1-6. Giant Dice faces are now 7-12.",
        "roll_values": [7, 8, 9, 10, 11, 12],
        "preview_face": 12,
        "accent": Color("47D65A"),  # heavy deep emerald
        "outline": Color("0F4018"),
        "aura_magic": Color(0.3, 0.85, 0.4, 0.9),
        "aura_accent": Color(0.15, 0.6, 0.25, 0.83),
    },
    "green": {
        "id": "gnome",
        "name": "Gnome Dice",
        "description": "Every time you roll a 1, Charge a Blue Dice.",
        "preview_face": 3,  # green is a d3
        "accent": Color("6CE05C"),
        "outline": Color("154A18"),
        "aura_magic": Color(0.42, 0.9, 0.35, 0.9),
        "aura_accent": Color(0.25, 0.65, 0.2, 0.83),
    },
    "mech": {
        "id": "clockwork",
        "name": "Clockwork Dice",
        "description": "You can add or subtract 1 Power twice after each roll.",
        "accent": Color("E0B24A"),  # brass/gears
        "outline": Color("4A3410"),
        "aura_magic": Color(0.95, 0.72, 0.28, 0.9),
        "aura_accent": Color(0.7, 0.5, 0.18, 0.83),
    },
    "magma": {
        "id": "inferno",
        "name": "Inferno Dice",
        "description": "The first roll each turn burns all enemies twice.",
        "accent": Color("FF8A2A"),  # white-hot lava
        "outline": Color("5A1A00"),
        "aura_magic": Color(1.0, 0.55, 0.15, 0.95),
        "aura_accent": Color(1.0, 0.78, 0.3, 0.85),
    },
    "odd": {
        "id": "bulwark",
        "name": "Bulwark Dice",
        "description": "Rolls give you Block equal to their value.",
        "preview_face": 7,  # odd is 1/3/5/7
        "accent": Color("5FB6E8"),  # defensive steel-blue
        "outline": Color("0C2E4A"),
        "aura_magic": Color(0.4, 0.7, 0.95, 0.9),
        "aura_accent": Color(0.2, 0.45, 0.8, 0.83),
    },
    "even": {
        "id": "octet",
        "name": "Octet Dice",
        "description": "When you roll an 8, gain 8 Strength for this turn only.",
        "preview_face": 8,  # even is 2/4/6/8
        "accent": Color("FF6B4A"),
        "outline": Color("4D1200"),
        "aura_magic": Color(1.0, 0.42, 0.28, 0.9),
        "aura_accent": Color(0.85, 0.28, 0.18, 0.83),
    },
}


static func has_infusion_for(dice_type: String) -> bool:
    return INFUSIONS.has(dice_type)


static func get_info(dice_type: String) -> Dictionary:
    return INFUSIONS.get(dice_type, {})


# The value 6 face shown big on the infusion screen isn't valid for every die (Green is a
# d3, Even/Odd top out at 8/7, Giant at 12) - each infusion can name its representative face.
static func preview_face(dice_type: String) -> int:
    return int(get_info(dice_type).get("preview_face", 6))


# For infusions that change which values the die can roll (Repented -> [6,6,6],
# Bulky -> [7..12]): returns the overriding value list, or [] if this die's infusion (or
# lack of one) doesn't change its faces. Applied in BOTH the real roll (dice.gd::roll_dice)
# and the Scout outcome preview (battle.gd) so they never disagree.
static func roll_values_override(dice_type: String) -> Array:
    if not Global.is_dice_infused(dice_type):
        return []
    return get_info(dice_type).get("roll_values", [])


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
