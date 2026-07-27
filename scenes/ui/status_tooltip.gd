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
        "infused":
            text = "Your dice rolls gain 2 power."
        "canalize":
            text = "If your power exceeds 9, gain 3 strength."
        "chaos":
            text = "When you roll a Dice, discard 1 random card. Then, draw a card."
        "exposed":
            text = "Take 50% more damage."
        "ink":
            text = "Your Power is hidden. Lose 1 ink stack every time you play a Card."
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
            text = "You deal double damage with Red Dice"
        "marionette":
            text = "At the start of each turn, gain a Scout 2 card"
        "sigil":
            text = "Everytime your power hits exactly the Sigil number, gain 1 Blue Dice. The Sigil number changes every turn."
        "greedy":
            text = "Gains 2 Strength for every 6 dice rolled this fight."
        "parasite":
            # Read off ParasiteStatus's own constants rather than retyped here: those two
            # numbers are the tuning dial for how greedy the player may be, and the last time
            # they moved (3/15 -> 2/18) this line silently kept promising the old ones.
            text = "Gains %d Strength the first time you generate more than %d Power in a turn." % [
                ParasiteStatus.PARASITE_STRENGTH, ParasiteStatus.PARASITE_THRESHOLD]
        "depleted":
            text = "You have 1 less Blue Dice next turn for each stack."
        "energized":
            text = "You have X more Blue Dice next turn."
        "serenity":
            text = "You draw 1 more Card each turn."
        "emanation":
            text = "You have 1 more Blue Dice each turn for the rest of the fight."
        "eclipse":
            text = "The next card you play does not reset your Power"
        _:
            text = status.tooltip if status.tooltip != "" else "No description available."

    # Upgraded blessings reuse their base status with a "_plus" id - the player-facing
    # name stays the base name ("Marionette", never "Marionette Plus").
    title_bbcode = "[center][color=gold][b]" + status.id.trim_suffix("_plus").capitalize() + "[/b][/color][/center]"
    var text_bbcode = "[b][center]" + text + "[/center][/b]"

    tooltip_title.bbcode_enabled = true
    tooltip_title.bbcode_text = title_bbcode

    tooltip_label.bbcode_enabled = true
    tooltip_label.bbcode_text = text_bbcode

    
