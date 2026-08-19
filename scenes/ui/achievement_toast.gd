extends Control

# Steam-style achievement popup: slides in from the bottom-right, holds, slides back out,
# then emits finished (the AchievementManager autoload frees it and shows the next queued
# one). Built entirely in code - same reasoning as tutorial_overlay.gd's panels: the
# global Cinzel theme is unreadable at body-text sizes, and the node lives on the
# manager's own CanvasLayer so screen coordinates are the fixed 1280x720 design canvas.
#
# The panel SELF-SIZES to its description (see _resize_to_content). It used to be a fixed
# 372x128 with a deliberately roomy 66px description box, sized so the longest achievement
# text ("Land a killing blow for at least 15 more damage...") couldn't overflow - which left
# a big dead gap under the short ones ("Reach 15 Power."). Two earlier attempts to pick a
# fixed height by modelling the wrap in PIL both under-measured (Godot rasterizes a few %
# wider with taller line spacing), so this stops modelling: the description sits in a
# VBoxContainer at a fixed width, we let Godot lay it out for one frame, then read the real
# wrapped height back off the container. The toast is parked off-screen for that frame, so
# the layout pass is never visible.

signal finished

const CANVAS := Vector2(1280, 720)
const TOAST_WIDTH := 372.0
# Floor so the trophy (56px) plus breathing room always fits, even on a one-line
# description - without it a short toast would collapse into a thin strip.
const TOAST_MIN_HEIGHT := 88.0
const MARGIN := Vector2(18, 16)
const SLIDE_IN_TIME := 0.45
const HOLD_TIME := 3.8
const SLIDE_OUT_TIME := 0.35

# Trophy on the left, text column to its right; PAD_BOTTOM mirrors TEXT_TOP closely
# enough that the text block reads optically centred at any height.
const ICON_LEFT := 16.0
const ICON_SIZE := 56.0
const TEXT_LEFT := 86.0
const TEXT_TOP := 11.0
const TEXT_WIDTH := 272.0
const PAD_BOTTOM := 13.0

const TITLE_FONT := preload("res://fonts/CinzelDecorative-Bold.otf")
const BODY_FONT := preload("res://Belwe Bold/Belwe Bold.otf")
const TROPHY_TEXTURE := preload("res://assets/images/achievement_trophy.png")

# Same palette as the pause menu panel.
const PANEL_BG := Color(0.101961, 0.227451, 0.235294)
const PANEL_BORDER := Color(0.784314, 0.658824, 0.294118)
const GOLD := Color(1, 0.843137, 0)
const CREAM := Color(0.92549, 0.890196, 0.815686)
const DIM := Color(0.72, 0.68, 0.56)

var _name_text := ""
var _desc_text := ""
var _panel: Panel
var _icon: TextureRect
var _text_column: VBoxContainer


func setup(achievement_name: String, achievement_desc: String) -> void:
	_name_text = achievement_name
	_desc_text = achievement_desc


func _ready() -> void:
	# Never block clicks on whatever the toast slides over.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(TOAST_WIDTH, TOAST_MIN_HEIGHT)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_border_width_all(3)
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.texture = TROPHY_TEXTURE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.pivot_offset = Vector2(ICON_SIZE, ICON_SIZE) / 2.0
	_panel.add_child(_icon)

	# Fixed-width column: the labels wrap inside it and the VBox reports the total height
	# back to us once Godot has laid it out.
	_text_column = VBoxContainer.new()
	_text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_column.position = Vector2(TEXT_LEFT, TEXT_TOP)
	_text_column.size = Vector2(TEXT_WIDTH, 0)
	_text_column.add_theme_constant_override("separation", 2)
	_panel.add_child(_text_column)

	_text_column.add_child(_make_label("ACHIEVEMENT UNLOCKED", TITLE_FONT, 11, GOLD))
	_text_column.add_child(_make_label(_name_text, BODY_FONT, 20, CREAM))
	var desc := _make_label(_desc_text, BODY_FONT, 12, DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_column.add_child(desc)

	# Park off-screen right (where the slide-in starts anyway) so the one un-sized frame
	# below is invisible, then let Godot wrap the description before we read its height.
	position = Vector2(CANVAS.x + 12, CANVAS.y - TOAST_MIN_HEIGHT - MARGIN.y)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_resize_to_content()
	_animate()


# Fits the panel to the laid-out text column instead of a hardcoded height, so short and
# long descriptions both sit in a snug card. SceneTree.process_frame (awaited above) fires
# even while the tree is paused, so this still runs when a toast pops over the pause menu.
func _resize_to_content() -> void:
	var content_height: float = _text_column.get_combined_minimum_size().y
	var height: float = maxf(TOAST_MIN_HEIGHT, TEXT_TOP + content_height + PAD_BOTTOM)
	size = Vector2(TOAST_WIDTH, height)
	_panel.size = size
	# Both the trophy and the text block are centred against the final height rather than
	# top-anchored. A one-line description doesn't fill TOAST_MIN_HEIGHT (that floor exists
	# for the 56px trophy, not the text), so top-anchoring left a visible gap under the text
	# and put it out of line with the trophy; centring both keeps them level at any height.
	_text_column.size = Vector2(TEXT_WIDTH, content_height)
	_text_column.position = Vector2(TEXT_LEFT, (height - content_height) / 2.0)
	_icon.position = Vector2(ICON_LEFT, (height - ICON_SIZE) / 2.0)


func _make_label(text_value: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text_value
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 0.6)
	label.label_settings = settings
	return label


func _animate() -> void:
	var on_screen_x := CANVAS.x - TOAST_WIDTH - MARGIN.x
	var y := CANVAS.y - size.y - MARGIN.y
	position = Vector2(CANVAS.x + 12, y)

	var tween := create_tween()
	tween.tween_property(self, "position:x", on_screen_x, SLIDE_IN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Little trophy punch once the panel has landed.
	tween.tween_callback(_punch_icon)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(self, "position:x", CANVAS.x + 12, SLIDE_OUT_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): finished.emit())


func _punch_icon() -> void:
	var tween := create_tween()
	tween.tween_property(_icon, "scale", Vector2(1.18, 1.18), 0.09) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(_icon, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
