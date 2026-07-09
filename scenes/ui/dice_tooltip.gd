extends Panel


@onready var tooltip_label: RichTextLabel = %TooltipText
@onready var tooltip_title: RichTextLabel = %TooltipTitle
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer

func show_tooltip(global_pos: Vector2) -> void:
    # Now parented under a CanvasLayer (see dice_tooltip.tscn) instead of directly
    # under get_tree().root, so get_parent() is the CanvasLayer, which has no
    # get_canvas_transform() (that's a Viewport method) - global_position already
    # accounts for canvas transforms on its own, same as tooltip.gd's relic tooltip.
    global_position = global_pos
    show()



func hide_tooltip() -> void:
    hide()

func get_tooltip_content(dice):
    var dice_keyword := "%s Dice" % dice.capitalize()
    tooltip_label.text = KeywordColorizer.DICE_TOOLTIP_TEXT.get(dice_keyword, "")
    tooltip_title.text = "[center][color=gold][b]%s[/b][/color][/center]" % dice_keyword
