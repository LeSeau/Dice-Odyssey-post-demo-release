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


# Where the caller asked for, kept so _fit_to_content() can re-clamp against the final height.
var _requested_pos := Vector2.ZERO

# Bottom-anchored mode. When _anchor_bottom_y >= 0 the tooltip is placed by its BOTTOM edge,
# centred on _anchor_center_x, growing UPWARD as its text gets taller - never above
# _anchor_min_top. Callers that must sit above a fixed piece of UI need this: anchoring by
# the top-left makes a tall tooltip grow DOWN into the very thing it was meant to clear,
# which is exactly how the combat dice tooltip used to bury the dice row.
var _anchor_bottom_y := -1.0
var _anchor_center_x := 0.0
var _anchor_min_top := 0.0


func show_tooltip_above(bottom_y: float, center_x: float, min_top: float) -> void:
    _anchor_bottom_y = bottom_y
    _anchor_center_x = center_x
    _anchor_min_top = min_top
    show()
    _apply_bottom_anchor()
    _fit_to_content()


func _apply_bottom_anchor() -> void:
    var top: float = maxf(_anchor_min_top, _anchor_bottom_y - size.y)
    global_position = _clamped_to_screen(Vector2(_anchor_center_x - size.x / 2.0, top))


func show_tooltip(global_pos: Vector2) -> void:
    # Now parented under a CanvasLayer (see dice_tooltip.tscn) instead of directly
    # under get_tree().root, so get_parent() is the CanvasLayer, which has no
    # get_canvas_transform() (that's a Viewport method) - global_position already
    # accounts for canvas transforms on its own, same as tooltip.gd's relic tooltip.
    _requested_pos = global_pos
    global_position = _clamped_to_screen(global_pos)
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
    # Re-place now that the real height is known: show_tooltip() could only clamp against the
    # authored 88px, so a tall infusion tooltip spawned low would still hang off the bottom.
    if _anchor_bottom_y >= 0.0:
        _apply_bottom_anchor()
    else:
        global_position = _clamped_to_screen(_requested_pos)



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
