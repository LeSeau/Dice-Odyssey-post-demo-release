extends Panel

@onready var vbox := $VBoxContainer

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

    if requirement == "MAX":
        text += "Your power cannot exceed this value\n"
    elif requirement == "MIN":
        text += "Your power must be at least this value"
    elif requirement == "RED":
        text += "Must be played on a Red Dice"
    elif requirement == "MULTIPLE":
        text += "Your power must be a multiple of this value"
    elif requirement == "EXACT":
        text += "Your power must be exactly this value"
    elif requirement == "EVEN":
        text += "Your power must be an even number"
    elif requirement == "ODD":
        text += "Your power must be an odd number"
    elif requirement == "Charge":
        text += "Gain 1 Dice this turn. If no Dice type is mentioned, it matches your active Dice."
    elif requirement == "Refuel":
        text += "Regain 1 Dice for each consecutive roll of the same Dice type"
    elif requirement == "Exhaust":
        text += "Can play this card only once per battle"
    elif KeywordColorizer.DICE_TOOLTIP_TEXT.has(requirement):
        text += KeywordColorizer.DICE_TOOLTIP_TEXT[requirement]
    elif requirement == "Lucky":
        text += "Your next roll will be the highest possible outcome."
    elif requirement == "Unlucky":
        text += "Your next roll will be the lowest possible outcome."
    elif requirement == "Depleted":
        text += "You have 1 less Dice next turn for each stack."
    elif requirement == "Energized":
        text += "You have X more Blue Dice next turn."
    elif requirement == "Infused":
        text += "Your dice rolls gain 2 power"
    elif requirement == "Exposed":
        text += "Take 50% more damage."
    elif requirement == "Weak":
        text+= "Your next roll loses 1 power per stack."
    elif requirement == "Strength":
        text += "Deal X more damage on each attack."
    elif requirement == "Scout":
        text += "See X possible outcomes for your next roll and choose one to guarantee"
    elif requirement == "Boost":
        text += "Increases your Power after your next roll"
    elif requirement == "Throw":
        text += "Rolls a bonus Dice without using any of your own"
    elif requirement == "Support":
        text += "Cards that don't attack or block but instead manipulate Power"
    elif requirement == "Power":
        text += "The sum of your consecutive rolls on the same Dice type. Cards with [img=13]res://power_glyph.png[/img] use this number."
    elif requirement == "REST":
        text += "Heal 33% of your Max HP"
    elif requirement == "UPGRADE":
        text += "Permanently improve a card in your deck"
    elif requirement == "Blessing":
        text += "A lasting effect for the rest of the combat. Exhausts when played."
    elif requirement == "Celestial":
        text += "This card does not need Power or Dice to be played. It does not reset Power after being played."
    elif requirement == "Common":
        text += "A Common card."
    elif requirement == "Uncommon":
        text += "An Uncommon card."
    elif requirement == "Rare":
        text += "A Rare card."
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
    
