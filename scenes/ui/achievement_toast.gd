extends Control

# Steam-style achievement popup: slides in from the bottom-right, holds, slides back out,
# then emits finished (the AchievementManager autoload frees it and shows the next queued
# one). Built entirely in code - same reasoning as tutorial_overlay.gd's panels: the
# global Cinzel theme is unreadable at body-text sizes, and the node lives on the
# manager's own CanvasLayer so screen coordinates are the fixed 1280x720 design canvas.

signal finished

const CANVAS := Vector2(1280, 720)
const TOAST_SIZE := Vector2(354, 92)
const MARGIN := Vector2(18, 16)
const SLIDE_IN_TIME := 0.45
const HOLD_TIME := 3.8
const SLIDE_OUT_TIME := 0.35

const TITLE_FONT := preload("res://fonts/CinzelDecorative-Bold.otf")
const BODY_FONT := preload("res://assets/static/Roboto_Condensed-SemiBold.ttf")
const TROPHY_TEXTURE := preload("res://assets/images/achievement_trophy.png")

# Same palette as the pause menu panel.
const PANEL_BG := Color(0.101961, 0.227451, 0.235294)
const PANEL_BORDER := Color(0.784314, 0.658824, 0.294118)
const GOLD := Color(1, 0.843137, 0)
const CREAM := Color(0.92549, 0.890196, 0.815686)
const DIM := Color(0.72, 0.68, 0.56)

var _name_text := ""
var _desc_text := ""
var _icon: TextureRect


func setup(achievement_name: String, achievement_desc: String) -> void:
	_name_text = achievement_name
	_desc_text = achievement_desc


func _ready() -> void:
	# Never block clicks on whatever the toast slides over.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = TOAST_SIZE

	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = TOAST_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_border_width_all(3)
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.texture = TROPHY_TEXTURE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.position = Vector2(16, 18)
	_icon.size = Vector2(56, 56)
	_icon.pivot_offset = Vector2(28, 28)
	panel.add_child(_icon)

	panel.add_child(_make_label(
		"ACHIEVEMENT UNLOCKED", TITLE_FONT, 11, GOLD, Vector2(86, 12), Vector2(252, 16)))
	panel.add_child(_make_label(
		_name_text, BODY_FONT, 20, CREAM, Vector2(86, 30), Vector2(252, 26)))
	var desc := _make_label(_desc_text, BODY_FONT, 13, DIM, Vector2(86, 56), Vector2(252, 32))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc)

	_animate()


func _make_label(
	text_value: String, font: Font, font_size: int, color: Color,
	pos: Vector2, label_size: Vector2
) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text_value
	label.position = pos
	label.size = label_size
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 0.6)
	label.label_settings = settings
	return label


func _animate() -> void:
	var on_screen_x := CANVAS.x - TOAST_SIZE.x - MARGIN.x
	var y := CANVAS.y - TOAST_SIZE.y - MARGIN.y
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
