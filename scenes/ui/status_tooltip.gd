extends Panel

# (Removed a dead `@onready var vbox := $VBoxContainer`: the node actually lives at
# MarginContainer/VBoxContainer, so it resolved to null and printed a "Node not found" error
# every single time a status tooltip spawned. Nothing ever read it.)
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
            text = "At the end of its turn, this enemy gains Strength equal to your last roll."
        "loaded":
            text = "Your Dice rolls gain that much bonus Power."
        "canalize":
            # Read off CanalizeStatus's own constants rather than retyped here - same reason as
            # Parasite below: these are the tuning dial, and when the Strength moved 3 -> 2
            # (Dragonpriest retune, 2026-07-28) this line kept promising the old number.
            text = "Each time your Power climbs above %d, this enemy gains %d Strength." % [
                CanalizeStatus.CANALIZE_THRESHOLD, CanalizeStatus.CANALIZE_STRENGTH]
        "chaos":
            text = "When you roll a Dice, discard 1 random card. Then, draw a card."
        "exposed":
            text = "Take 50% more damage. Wears off by 1 each turn."
        "ink":
            text = "Hides your Power. Playing a card removes 1 stack."
        "strength":
            # Subject-less on purpose - this same string is shown on ENEMY Strength badges.
            text = "Attacks deal this much more damage."
        "true_strength":
            text = "Gains %d Strength each turn." % TrueStrengthStatus.STRENGTH_PER_TURN
        "weak":
            text = "Your next roll loses 1 Power per stack, then it wears off."
        "lucky":
            text = "Your next roll lands on the highest possible face. One roll per stack."
        "unlucky":
            text = "Your next roll lands on the lowest possible face. One roll per stack."
        "flux":
            text = "This enemy prevents you from rolling the same Dice type twice in a row."
        "berserk":
            text = "You deal double damage with Red Dice."
        # NOTE: no "marionette" case on purpose. Its .tres tooltip is already correct AND the
        # "+" variant (id "marionette_plus") never matched here anyway, so it fell through to
        # the .tres regardless - meaning a hardcoded entry could only ever drift from its own
        # upgrade. It had: it promised "Scout 2" while the card grants Scout 3.
        "sigil":
            # "this number" points at the badge, which IS the Sigil number - same house
            # pattern as Earthquake's "deal this much damage". Kept to 3 lines: the panel is
            # fixed-height and a 4th line spills (measured, debug_tooltip_fit.gd).
            text = "Match this number with your Power to gain 1 Blue Dice. It changes each turn."
        "greedy":
            text = "Gains 2 Strength for every 6 Dice rolled this fight."
        "parasite":
            # Read off ParasiteStatus's own constants rather than retyped here: those two
            # numbers are the tuning dial for how greedy the player may be, and the last time
            # they moved (3/15 -> 2/18) this line silently kept promising the old ones.
            text = "Gains %d Strength the first time you generate more than %d Power in a turn." % [
                ParasiteStatus.PARASITE_STRENGTH, ParasiteStatus.PARASITE_THRESHOLD]
        "depleted":
            text = "You have 1 less Blue Dice next turn for each stack."
        "energized":
            text = "You have 1 more Blue Dice next turn."
        "serenity":
            text = "You draw 1 more Card each turn."
        "emanation":
            text = "You have 1 more Blue Dice each turn for the rest of the fight."
        "eclipse":
            text = "The next card you play does not reset your Power."
        _:
            text = status.tooltip if status.tooltip != "" else "No description available."

    # Upgraded blessings reuse their base status with a "_plus" id - the player-facing
    # name stays the base name ("Marionette", never "Marionette Plus").
    title_bbcode = "[center][color=gold][b]" + status.id.trim_suffix("_plus").capitalize() + "[/b][/color][/center]"
    # Same treatment as card text: dice names in their color, keywords gold, Power glyphed.
    # 14px glyph = body font 12 + 2 (the cards' font+2 convention).
    var text_bbcode = "[b][center]" + KeywordColorizer.colorize_tooltip(text, 14) + "[/center][/b]"

    tooltip_title.bbcode_enabled = true
    tooltip_title.bbcode_text = title_bbcode

    tooltip_label.bbcode_enabled = true
    tooltip_label.bbcode_text = text_bbcode

    
