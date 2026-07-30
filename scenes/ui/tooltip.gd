extends Panel

@onready var tooltip_label: RichTextLabel = %TooltipText
@onready var tooltip_title: RichTextLabel = %TooltipTitle



func show_tooltip(global_pos: Vector2) -> void:
    global_position = global_pos
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
    elif requirement == "Infused":
        text += "Your Dice rolls gain 2 Power."
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
        text += "Rolls a bonus Dice without using any of your own."
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
    elif requirement == "Common":
        text += "The most frequent card rarity."
    elif requirement == "Uncommon":
        text += "Less common, with stronger effects."
    elif requirement == "Rare":
        text += "The rarest and most powerful cards."
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
    if requirement == "Power":
        # The resource's own tooltip leads with its glyph - this pairing is what teaches
        # players that the inline icon IS Power.
        title_text = "[img=18]res://power_glyph.png[/img] " + title_text
    tooltip_label.text = text
    tooltip_title.text = title_text
    
