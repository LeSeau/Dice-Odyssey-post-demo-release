extends Panel

@onready var tooltip_label: RichTextLabel = %TooltipText
@onready var tooltip_title: RichTextLabel = %TooltipTitle



func show_tooltip(global_pos: Vector2) -> void:
    # Callers position off whatever is being hovered, which near a screen edge used to put
    # the panel partly outside the viewport (it just gets clipped - nothing scrolls it back).
    # Clamping here covers every spawn site at once, including the fixed-position ones.
    global_position = _clamped_to_screen(global_pos)
    show()



func hide_tooltip() -> void:
    hide()

func get_tooltip_content(requirement):
    var text := ""
    var title_text := ""

    # "Power" is capitalized everywhere in this table: it's the name of a resource the player
    # sees spelled that way on every card and in the HUD, so lowercase "power" read as a
    # different, generic word.
    if requirement == "MAX":
        text += "Your Power must be this value or less."
    elif requirement == "MIN":
        text += "Your Power must be at least this value."
    elif requirement == "RED":
        text += "Must be played on a Red Dice."
    elif requirement == "MULTIPLE":
        text += "Your Power must be a multiple of this value."
    elif requirement == "EXACT":
        text += "Your Power must be exactly this value."
    elif requirement == "EVEN":
        text += "Your Power must be an even number."
    elif requirement == "ODD":
        text += "Your Power must be an odd number."
    elif requirement == "Charge":
        text += "Gain that many Dice this turn. If no type is named, they match your active Dice."
    elif requirement == "Refuel":
        text += "Regain 1 Dice for each consecutive roll of the same Dice type."
    elif requirement == "Exhaust":
        text += "Once played, the card is removed for the rest of the fight."
    elif KeywordColorizer.DICE_TOOLTIP_TEXT.has(requirement):
        text += KeywordColorizer.DICE_TOOLTIP_TEXT[requirement]
    elif requirement == "Lucky":
        text += "Your next roll lands on the highest possible face. One roll per stack."
    elif requirement == "Unlucky":
        text += "Your next roll lands on the lowest possible face. One roll per stack."
    elif requirement == "Depleted":
        # Blue specifically: Electrify (the only source) hands out Odd dice and charges the
        # cost in Blue, so a generic "1 less Dice" would hide which slot actually shrinks.
        text += "You have 1 less Blue Dice next turn for each stack."
    elif requirement == "Energized":
        text += "You have 1 more Blue Dice next turn."
    elif requirement == "Surge":
        text += "Your Dice rolls gain that much bonus Power."
    elif requirement == "Exposed":
        text += "Take 50% more damage. Wears off by 1 each turn."
    elif requirement == "Weak":
        text += "Your next roll loses 1 Power per stack, then it wears off."
    elif requirement == "Strength":
        # Subject-less on purpose: the same string is shown for ENEMY Strength badges, so
        # "you deal" would be wrong half the time.
        text += "Attacks deal this much more damage."
    elif requirement == "Scout":
        text += "See that many possible rolls and pick one to be your next roll."
    elif requirement == "Boost":
        text += "Adds that much Power to your next roll."
    elif requirement == "Throw":
        # ⚠️ Must not say "roll". A thrown Dice is NOT one of your rolls (2026-08-29): it does
        # not build Power and it does not count for anything that reacts to rolling a Dice.
        # This one line is where the player learns that, so keep the distinction explicit.
        text += "An extra Dice that resolves on its own. It builds no Power and never counts as a roll."
    elif requirement == "Reroll":
        # Ricochet's native ability, which Quicksilver grafts onto another type. Worded from
        # the player's side ("you may") because the choice is theirs and it is optional.
        text += "Once per roll, you may roll that Dice again and keep the new result."
    elif requirement == "Support":
        text += "Cards that don't attack or block but instead manipulate Power."
    elif requirement == "Power":
        text += "The sum of your consecutive rolls on the same Dice type. Cards with [img=13]res://power_glyph.png[/img] use this number."
    elif requirement == "REST":
        text += "Heal 33% of your Max HP."
    elif requirement == "UPGRADE":
        text += "Permanently improve a card in your deck."
    elif requirement == "Blessing":
        text += "A lasting effect for the rest of the combat. Exhausts when played."
    elif requirement == "Celestial":
        # The panel is fixed-height and silently clips past 3 lines; the old 95-char version
        # sat right on that limit.
        text += "Needs no Dice or Power to play, and doesn't reset your Power."
    # Rarity: say how often you'll see it AND what to expect from it. "A Common card." was
    # circular, and "the most frequent card rarity" told the player nothing they could act on.
    # The Rare line spends its third sentence on the one genuinely actionable fact - every
    # boss reward is Rare - since that's what turns rarity from flavour into run planning.
    elif requirement == "Common":
        text += "The most frequently offered cards, with the simplest effects."
    elif requirement == "Uncommon":
        text += "Offered less often, with stronger or more specialized effects."
    elif requirement == "Rare":
        text += "Rarely offered, and the most powerful. Every boss reward is Rare."
    #if bonus_requirement == "MAX":
        #text += "Your power cannot exceed this value\n"
    #elif bonus_requirement == "MIN":
        #text += "Your power must be at least this value"
    #elif bonus_requirement == "RED":
        #text += "Must be played on a Red Dice"
    #elif bonus_requirement == "MULTIPLE":
        #text += "Your power must be a multiple of this value"
    #elif bonus_requirement == "EXACT":
        #text += "Your power must be exactly this value"
    #elif bonus_requirement == "EVEN":
        #text += "Your power must be an even number"
    #elif bonus_requirement == "ODD":
        #text += "Your power must be an odd number"
    
    title_text = "[color=gold][b]%s[/b][/color]" % requirement
    if KeywordColorizer.DICE_KEYWORD_COLORS.has(requirement):
        # Dice-type tooltips wear their die's own color in the title, same as the dice-shop
        # hover tooltip already does - gold is for keywords, dice keep their identity color.
        title_text = "[color=#%s][b]%s[/b][/color]" % [
            KeywordColorizer.DICE_KEYWORD_COLORS[requirement], requirement]
    if requirement == "Power":
        # The resource's own tooltip leads with its glyph - this pairing is what teaches
        # players that the inline icon IS Power.
        title_text = "[img=18]res://power_glyph.png[/img] " + title_text
    # Same treatment as card text: dice names in their color, keywords gold, Power glyphed.
    # 13px glyph = body font 11 + 2, the same size the Power entry hand-authors above.
    tooltip_label.text = KeywordColorizer.colorize_tooltip(text, 13)
    tooltip_title.text = title_text
    


# Inlined rather than calling Global: these panel scripts are reached through `const ... =
# preload(...)` chains (intent_ui.gd), and resolving the Global autoload from here fails at
# that point - the script then binds as a plain Panel and every show_tooltip() call errors
# with "Nonexistent function 'show_tooltip' in base 'Panel'". Keep this self-contained.
func _clamped_to_screen(pos: Vector2) -> Vector2:
    const MARGIN := 8.0
    var view: Vector2 = get_viewport_rect().size
    return Vector2(
        clampf(pos.x, MARGIN, maxf(MARGIN, view.x - size.x - MARGIN)),
        clampf(pos.y, MARGIN, maxf(MARGIN, view.y - size.y - MARGIN)))
