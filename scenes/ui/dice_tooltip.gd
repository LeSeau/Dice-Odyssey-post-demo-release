extends Panel


@onready var tooltip_label: RichTextLabel = %TooltipText
@onready var tooltip_title: RichTextLabel = %TooltipTitle
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var margin_container: MarginContainer = $MarginContainer


func _ready() -> void:
    # Grow-with-content: the .tscn's fixed 204x88 panel was sized for the short base
    # tooltips ("Faces: ..."), but an infused die (act-2 dice infusions) appends an
    # effect line that clips at that height (spotted on Berserker). fit_content makes
    # each label's minimum height track its text so _fit_to_content() can measure the
    # real need. Text is always set (get_tooltip_content) AFTER instantiation/_ready,
    # so flipping these here covers every call site.
    tooltip_title.fit_content = true
    tooltip_label.fit_content = true


func show_tooltip(global_pos: Vector2) -> void:
    # Now parented under a CanvasLayer (see dice_tooltip.tscn) instead of directly
    # under get_tree().root, so get_parent() is the CanvasLayer, which has no
    # get_canvas_transform() (that's a Viewport method) - global_position already
    # accounts for canvas transforms on its own, same as tooltip.gd's relic tooltip.
    global_position = global_pos
    show()
    _fit_to_content()


func _fit_to_content() -> void:
    # One frame so the VBox has laid the labels out at their real width - RichTextLabel
    # can't report a content height before it knows how wide it is. If the tooltip is
    # freed mid-await (fast hover-out), the coroutine dies silently with the node.
    await get_tree().process_frame
    var content_height: float = vbox.get_combined_minimum_size().y
    # + MarginContainer's top(8)/bottom(6) margins + its 2px inset from each panel edge
    # (the fixed offsets in dice_tooltip.tscn).
    var panel_height: float = content_height + 8.0 + 6.0 + 4.0
    panel_height = maxf(panel_height, 88.0)  # never smaller than the authored base look
    size.y = panel_height
    margin_container.offset_bottom = panel_height - 2.0



func hide_tooltip() -> void:
    hide()

func get_tooltip_content(dice):
    var dice_keyword := "%s Dice" % KeywordColorizer.dice_display_name(dice)
    var body: String = KeywordColorizer.DICE_TOOLTIP_TEXT.get(dice_keyword, "")
    var title := dice_keyword
    var title_color := "gold"
    # An infused die (act-2 dice infusion) renames its tooltip and appends the infusion
    # effect line, both in the infusion's own accent color.
    if Global.is_dice_infused(dice):
        var info: Dictionary = DiceInfusions.get_info(dice)
        if not info.is_empty():
            title = info["name"]
            var accent_hex: String = info["accent"].to_html(false)
            title_color = "#" + accent_hex
            if body != "":
                body += "\n"
            body += "[color=#%s]%s[/color]" % [accent_hex, info["description"]]
    tooltip_label.text = body
    tooltip_title.text = "[center][color=%s][b]%s[/b][/color][/center]" % [title_color, title]
