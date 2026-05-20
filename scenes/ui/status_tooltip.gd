extends Panel

@onready var vbox := $VBoxContainer
@onready var tooltip_title: RichTextLabel = %TooltipTitle
@onready var tooltip_label: RichTextLabel = %TooltipText

func show_tooltip(global_pos: Vector2) -> void:
    global_position = global_pos
    # Show the popup first to ensure the window exists
    show()

    # Then make the window transparent
    get_window().transparent = true


func hide_tooltip() -> void:
    hide()

func get_tooltip_content(status: Status) -> void:
    var title_bbcode := ""
    var text := ""

    match status.id:
        "absorb":
            text = "At the end of their turn, gain strength equal to your last roll."
        "blessed":
            text = "Your dice rolls gain 2 power."
        "canalize":
            text = "If your power exceeds 9, gain 3 strength."
        "chaos":
            text = "When you roll a Dice, discard 1 random card. Then, draw a card."
        "exposed":
            text = "Take 50% more damage."
        "ink":
            text = "Your Power is hidden. Lose 1 ink stack every time you play a non-support Card."
        "strength":
            text = "Deal X more damage on each attack." 
        "true_strength":
            text = "Gain Strength each turn."
        "weak":
            text = "Your next roll loses 1 power per stack."
        "lucky":
            text = "Your next roll will be the highest possible outcome."
        "unlucky":
            text = "Your next roll will be the lowest possible outcome."
        "flux":
            text = "This enemy prevents you from rolling the same Dice type twice in a row."
        "berserk":
            text = "You deal 50% more damage with Red Dice"
        "marionette":
            text = "At the start of each turn, gain a Scout 2 card"
        "sigil":
            text = "Everytime your power hits exactly the Sigil number, gain 1 Blue Dice. The Sigil number changes every turn."
        "greedy":
            text = "Gains 1 Strength for every 6 dice rolled this fight."
        "parasite":
            text = "Gains 3 Strength if you generate more than 15 Power in the same turn."
        "depleted":
            text = "You have 1 less Blue Dice next turn for each stack."
        "energized":
            text = "You have 1 more Blue Dice next turn."
        "serenity":
            text = "You draw 1 more Card each turn."
        "emanation":
            text = "You have 1 more Blue Dice each turn for the rest of the fight."
        "eclipse":
            text = "The next card you play does not reset your Power"
        _:
            text = "No description available."

    title_bbcode = "[center][color=gold][b]" + status.id.capitalize() + "[/b][/color][/center]"
    var text_bbcode = "[b][center]" + text + "[/center][/b]"

    tooltip_title.bbcode_enabled = true
    tooltip_title.bbcode_text = title_bbcode

    tooltip_label.bbcode_enabled = true
    tooltip_label.bbcode_text = text_bbcode

    
