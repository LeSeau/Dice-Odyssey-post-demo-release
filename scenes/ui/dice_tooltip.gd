extends Panel


@onready var tooltip_label: RichTextLabel = %TooltipText
@onready var tooltip_title: RichTextLabel = %TooltipTitle
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer

func show_tooltip(global_pos: Vector2) -> void:
    # Convert global to local relative to parent
    position = get_parent().get_canvas_transform().affine_inverse() * global_pos
    show()



func hide_tooltip() -> void:
    hide()

func get_tooltip_content(dice):
    var dice_keyword := "%s Dice" % dice.capitalize()
    tooltip_label.text = KeywordColorizer.DICE_TOOLTIP_TEXT.get(dice_keyword, "")
    tooltip_title.text = "[center][color=gold][b]%s[/b][/color][/center]" % dice_keyword
