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
    elif requirement == "Green Dice":
        text += "Green Dice can roll 1-3"
    elif requirement == "Magma Dice":
        text += "Magma Dice can roll 1-6 and deals X damage to all enemies on each roll"
    elif requirement == "Giant Dice":
        text += "Giant Dice can roll 1-12"
    elif requirement == "Evil Dice":
        text += "Evil Dice can roll 6, 6, 6 and 0"
    elif requirement == "Lucky":
        text += "Your next roll will be the highest possible outcome."
    elif requirement == "Depleted":
        text += "You have X less Blue Dice next turn for each stack."
    elif requirement == "Energized":
        text += "You have X more Blue Dice next turn."
    elif requirement == "Blessed":
        text += "Your dice rolls gain 1 power"
    elif requirement == "Exposed":
        text += "Take 50% more damage."
    elif requirement == "Strength":
        text += "Deal X more damage on each attack."
    elif requirement == "Scout":
        text += "See 3 possible outcomes for your next roll and choose one to guarantee"
    elif requirement == "Boost":
        text += "Increases your Power after your next roll"
    elif requirement == "Support":
        text += "Cards that don't attack or block but instead manipulate Power"
    elif requirement == "REST":
        text += "Heal 22 HP"
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
    tooltip_label.text = text
    tooltip_title.text = title_text
    
