# Single source of truth for the per-dice-type UI colors, tuned by eye against the FINAL
# dice textures (2026-07-10, after the art was locked): each accent is the die's own dominant
# hue pushed to a readable UI brightness, so the Power number, orbs, popups, particles and
# card text all visibly belong to the die being rolled.
#
# Used by: dice.gd (Power number/outline, roll history, +X popup, power orbs, burst tints),
# card_particles.gd, damage_popup.gd, dice_interface.gd (selected-slot highlight).
# NOT used by (kept in sync by hand — update them together with this file):
# - keyword_colorizer.gd::DICE_KEYWORD_COLORS (needs literal hex strings in a const dict)
# - the 9 scenes/dices/*_dice_shader.tres aura materials (magic_color/accent_color, resource
#   values edited in the editor/file — same hue families as ACCENT below, darker/deeper)
class_name DicePalette
extends RefCounted

# Bright accent per type — the "identity" color used for text/particles on dark backgrounds.
const ACCENT := {
    "blue":  Color("3D7BFF"),  # cobalt leather
    "red":   Color("FF2F3E"),  # blood crimson (less orange than the old ff3322)
    "green": Color("48D147"),  # forest leaf (was mint 33ff99, didn't match the mossy die)
    "magma": Color("FF5A14"),  # lava orange
    "mech":  Color("B9C1CB"),  # light steel, matches the silvery pips/rivets
    # even/odd colours were EXCHANGED with the bodies in the Golem/Ricochet rework: the
    # internal type strings stayed put but the art swapped, so "even" (Golem) now wears the
    # cracked ochre body and "odd" (Ricochet) the orange one. Colour follows the body, not
    # the type string - do not "fix" these back by name.
    "even":  Color("E9B83D"),  # Golem: aged brass/ochre, cracked stone body
    "odd":   Color("FF9526"),  # Ricochet: saturated orange body
    "evil":  Color("E14FE1"),  # fuchsia crack-veins
    "giant": Color("A9D648"),  # moss lime on the stone boulder (was neon 99ff55)
}

# Deep same-hue shade per type — outlines behind the accent (Power number outline, etc.).
const OUTLINE := {
    "blue":  Color("071F52"),
    "red":   Color("4D0009"),
    "green": Color("0C3A10"),
    "magma": Color("4E1000"),
    "mech":  Color("1F2429"),
    "even":  Color("47360A"),  # Golem (ochre) - exchanged with odd, see ACCENT above
    "odd":   Color("592800"),  # Ricochet (orange) - exchanged with even, see ACCENT above
    "evil":  Color("3C0A44"),
    "giant": Color("2C3A0D"),
}

# Warm near-white the max-roll / charge bursts lerp toward, so every type's celebration
# keeps a golden "success" core while still reading as that die's color.
const BURST_WARM_WHITE := Color(1.0, 0.92, 0.6)


static func accent(type: String) -> Color:
    # An infused die (act-2 dice infusion) overrides its identity color here, at the
    # single source - power number, orbs, popups, particles and card glow all recolor
    # at once without touching any consumer. (The hand-synced consumers listed above -
    # keyword_colorizer, aura shader .tres - deliberately keep the BASE colors; the
    # aura gets its own infused recolor via dice.gd::_resolve_aura_material.)
    if Global.is_dice_infused(type):
        var info: Dictionary = DiceInfusions.get_info(type)
        if info.has("accent"):
            return info["accent"]
    return ACCENT.get(type, Color.WHITE)


static func outline(type: String) -> Color:
    if Global.is_dice_infused(type):
        var info: Dictionary = DiceInfusions.get_info(type)
        if info.has("outline"):
            return info["outline"]
    return OUTLINE.get(type, Color(0.08, 0.08, 0.08))


# Accent pulled partway toward warm white — for celebratory particle bursts (max roll,
# charge) that should read "golden success, tinted by this die" rather than pure type color.
static func burst(type: String, warmth: float = 0.45) -> Color:
    return accent(type).lerp(BURST_WARM_WHITE, warmth)
