class_name IconTooltip
extends Panel

# Compact, self-sizing single-line tooltip for icon-only buttons (top-bar Map/Dice Shop/
# Deck/Settings) - reuses the game's usual dark/gold panel (tooltip.tres, same as the
# card/relic/status/dice tooltips) instead of Godot's plain default tooltip_text popup,
# which looked out of place next to every other styled UI panel here.
#
# Same instantiate-on-hover/free-on-exit lifecycle as every other tooltip in the project
# (relic_ui.gd, card_ui.gd, dice_tooltip.gd - see the "Tooltip leak pattern" note): spawn
# fresh via spawn_below() on mouse_entered, queue_free() the stored instance on
# mouse_exited. The safety timeout below covers the same edge case those have (mouse_exited
# not firing) even though these particular buttons live on the persistent run.tscn root and
# are unlikely to be freed mid-hover.

const SCENE_PATH := "res://scenes/ui/icon_tooltip.tscn"
const MIN_HEIGHT := 44.0
const GAP_BELOW_ICON := 8.0
const SCREEN_MARGIN := 8.0
const SAFETY_TIMEOUT := 8.0

# Body variant for longer, multi-sentence explanations (map affordable-dice badge etc.) -
# Cinzel-Bold's lowercase glyphs are styled like small caps, which reads fine for the short
# single-word labels the other callers use ("Map", "Dice Shop"...) but makes a full sentence
# look shouted. Swaps in the same regular body font the game's other tooltips already use for
# description text (tooltip.tscn's TooltipText), left-aligned instead of centered/bold/gold,
# and widened since a sentence wrapped at 150px reads as an awkward narrow column.
const BODY_FONT := preload("res://Noto_Sans/static/NotoSans-Medium.ttf")
const BODY_FONT_SIZE := 13
const BODY_WIDTH := 260.0

@onready var label: RichTextLabel = %TooltipLabel
@onready var margin_container: MarginContainer = $MarginContainer


func _ready() -> void:
    label.fit_content = true


# Anchors below the given button (its own global rect), clamped so it never runs off the
# side of the screen. Returns the spawned CanvasLayer ROOT of the tooltip scene (NOT the
# Panel itself - icon_tooltip.tscn wraps the Panel in its own CanvasLayer at layer=100 so
# it reliably renders above the TopBar's own CanvasLayer, same reasoning as every other
# tooltip in the project - see the "CanvasLayer z-order" note: z_index never beats a
# CanvasLayer boundary). Callers should store the returned Node and free() it on
# mouse_exited - freeing the layer takes the whole tooltip subtree with it. Freeing just
# the inner Panel would leak an empty CanvasLayer per hover cycle.
static func spawn_below(button: Control, text: String) -> Node:
    # load(), not preload(): a top-level `const SCENE := preload(SCENE_PATH)` here would
    # try to resolve icon_tooltip.tscn (which attaches THIS SAME SCRIPT to a child node)
    # while this script is still being parsed - that circular resolution deadlocked
    # Godot at load time (confirmed: hung indefinitely on a headless run). Deferring to a
    # runtime load() call sidesteps it since the script is already fully loaded by then.
    var layer: Node = load(SCENE_PATH).instantiate()
    button.get_tree().root.add_child(layer)
    var panel: IconTooltip = layer.get_node("IconTooltip")
    var anchor := button.global_position + Vector2(button.size.x / 2.0, button.size.y)
    panel.show_tooltip(anchor, text)
    layer.get_tree().create_timer(SAFETY_TIMEOUT).timeout.connect(func():
        if is_instance_valid(layer):
            layer.queue_free()
    )
    return layer


func show_tooltip(anchor_bottom_center: Vector2, text: String) -> void:
    label.text = "[center][color=gold][b]%s[/b][/color][/center]" % text
    show()
    # One frame so the label has laid out at its real (fixed) width before measuring
    # how tall its content actually needs to be.
    await get_tree().process_frame
    var content_height: float = label.get_content_height()
    # + MarginContainer's top(8)/bottom(8) margins + its 2px inset from the panel edge.
    var panel_height: float = maxf(content_height + 16.0 + 4.0, MIN_HEIGHT)
    size.y = panel_height
    margin_container.offset_bottom = panel_height - 2.0

    var target_x := anchor_bottom_center.x - size.x / 2.0
    var viewport_width := get_viewport_rect().size.x
    target_x = clampf(target_x, SCREEN_MARGIN, viewport_width - size.x - SCREEN_MARGIN)
    global_position = Vector2(target_x, anchor_bottom_center.y + GAP_BELOW_ICON)


func hide_tooltip() -> void:
    hide()


# Same anchor-then-measure flow as show_tooltip(), but plain regular-font left-aligned text
# at a wider fixed width - see BODY_FONT const comment above for why. anchor_top_center is the
# point to appear just BELOW (unlike show_tooltip's anchor_bottom_center - callers spawning
# this from a small world-space badge pass the badge's own position, not a button's bottom
# edge, so "just below the anchor" is what actually reads correctly here).
func show_body_tooltip(anchor_top_center: Vector2, text: String) -> void:
    label.add_theme_font_override("normal_font", BODY_FONT)
    label.add_theme_font_override("bold_font", BODY_FONT)
    label.add_theme_font_size_override("normal_font_size", BODY_FONT_SIZE)
    label.add_theme_font_size_override("bold_font_size", BODY_FONT_SIZE)
    label.text = text
    size.x = BODY_WIDTH
    margin_container.offset_right = BODY_WIDTH - 2.0
    show()
    await get_tree().process_frame
    var content_height: float = label.get_content_height()
    var panel_height: float = maxf(content_height + 16.0 + 4.0, MIN_HEIGHT)
    size.y = panel_height
    margin_container.offset_bottom = panel_height - 2.0

    var target_x := anchor_top_center.x - size.x / 2.0
    var viewport_width := get_viewport_rect().size.x
    target_x = clampf(target_x, SCREEN_MARGIN, viewport_width - size.x - SCREEN_MARGIN)
    global_position = Vector2(target_x, anchor_top_center.y + GAP_BELOW_ICON)
