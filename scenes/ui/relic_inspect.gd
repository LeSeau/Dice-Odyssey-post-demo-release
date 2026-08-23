extends CanvasLayer

# Click a relic in the top bar and it opens here, Slay the Spire 2 style: the board dims, the
# relic is shown big with its name and description, and clicking anywhere closes it. The hover
# tooltip stays as-is for a quick read; this is the deliberate "let me actually look at it" view,
# which matters most on a late run where the bar holds a dozen 46px icons.
#
# Built entirely in code, same reasoning as achievement_toast.gd: the project's global Cinzel
# theme is unreadable at body-text sizes, and building here avoids hand-authoring a .tscn (and
# avoids adding one more resource for a live editor to re-save).
#
# Opened via the static helper, called through a preload rather than a class_name:
#     preload("res://scenes/ui/relic_inspect.gd").open(relic, self)
# Deliberately NO class_name - a freshly added one is missing from Godot's global class cache
# until the editor rescans, which breaks every headless run until then (documented trap).

const CANVAS := Vector2(1280, 720)
const PANEL_WIDTH := 468.0
const PANEL_MIN_HEIGHT := 250.0

const ICON_SIZE := 152.0
const PAD := 26.0
const TEXT_WIDTH := PANEL_WIDTH - PAD * 2.0

const TITLE_FONT := preload("res://fonts/Cinzel-Bold.otf")
const BODY_FONT := preload("res://Belwe Bold/Belwe Bold.otf")

# The tooltip/panel language used everywhere else: navy ground, thin gold border (see
# scenes/ui/tooltip.tres, whose values these mirror).
const PANEL_BG := Color(0.129412, 0.164706, 0.243137)
const PANEL_BORDER := Color(0.752941, 0.501961, 0.0627451)
const ICON_PLATE_BG := Color(0.09, 0.114, 0.169)
const GOLD := Color(0.933, 0.710, 0.165)
# Rarity label colours, matching the gems on card banners: stone for Common, a saturated blue
# for Uncommon, gold for Rare. Lightened from the gem art where needed so they stay legible as
# TEXT on the navy panel - a gem only has to be distinguishable, a word has to be readable.
const RARITY_COLORS := {
	Relic.RarityTier.COMMON: Color(0.62, 0.66, 0.72),
	Relic.RarityTier.UNCOMMON: Color(0.43, 0.62, 0.91),
	Relic.RarityTier.RARE: Color(0.933, 0.710, 0.165),
}
const RARITY_NAMES := {
	Relic.RarityTier.COMMON: "Common",
	Relic.RarityTier.UNCOMMON: "Uncommon",
	Relic.RarityTier.RARE: "Rare",
}
const CREAM := Color(1.0, 0.965, 0.886)
const DIM_TEXT := Color(0.60, 0.64, 0.72)
const OUTLINE := Color(0.09, 0.06, 0.02)

const FADE_IN := 0.14
const FADE_OUT := 0.10

var _relic: Relic
var _root: Control
var _panel: Panel
var _column: VBoxContainer
var _closing := false


# `host` only supplies the SceneTree - the popup parents itself to the root so it is never
# affected by the layout, visibility or pause state of whatever was clicked.
static func open(relic: Relic, host: Node) -> Node:
	if relic == null or host == null or not host.is_inside_tree():
		return null
	var inspect := new()
	inspect._relic = relic
	host.get_tree().root.add_child(inspect)
	return inspect


func _init() -> void:
	layer = 95
	# The map-consult mode pauses the tree; without ALWAYS the popup would freeze mid-fade and
	# stop accepting the click that closes it (the "stuck tooltip" bug class, one layer up).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Dimmer: also the click target. Anything behind it is unreachable while open, which is the
	# point - it is a modal, not an overlay.
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.68)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(_on_click_anywhere)
	_root.add_child(dimmer)

	_build_panel()

	# Park invisible for one frame so the self-sizing pass below is never seen, then fade in.
	_root.modulate.a = 0.0
	await get_tree().process_frame
	_resize_to_content()
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	# A small settle rather than a bounce: this is a reference panel, not a reward.
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.97, 0.97)
	var pop := create_tween()
	pop.tween_property(_panel, "scale", Vector2.ONE, FADE_IN + 0.05) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_MIN_HEIGHT)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_MIN_HEIGHT)
	# Clicking the panel closes it too - the hint says "anywhere", so it has to mean anywhere.
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_click_anywhere)
	_root.add_child(_panel)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	_column.position = Vector2(PAD, PAD)
	_column.custom_minimum_size.x = TEXT_WIDTH
	_column.size.x = TEXT_WIDTH
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_column)

	# --- icon on its own inset plate, so a dark relic still reads against the navy ---
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = ICON_PLATE_BG
	plate_style.border_color = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.45)
	plate_style.set_border_width_all(1)
	plate_style.set_corner_radius_all(6)

	var plate := Panel.new()
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(plate)

	var icon := TextureRect.new()
	icon.texture = _relic.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# KEEP_ASPECT_CENTERED, not COVERED: the top bar crops to fill a small square, but here
	# there is room to show the whole icon, and a non-square relic should not lose its edges.
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(icon)

	# --- name + rarity, kept tight together as one block so the rarity reads as a subtitle
	# of the name rather than as a third, equally-weighted line ---
	var name_block := VBoxContainer.new()
	name_block.add_theme_constant_override("separation", 1)
	name_block.custom_minimum_size.x = TEXT_WIDTH
	name_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(name_block)

	var title := Label.new()
	title.text = _relic.relic_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = TEXT_WIDTH
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", OUTLINE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_block.add_child(title)

	# Uppercase and letter-spaced so it reads as a LABEL next to the name rather than as more
	# prose - the same move the rarity chips use elsewhere. Godot's Label has no letter-spacing
	# property, so it comes from a FontVariation.
	var rarity_font := FontVariation.new()
	rarity_font.base_font = TITLE_FONT
	rarity_font.spacing_glyph = 2

	var rarity := Label.new()
	rarity.text = String(RARITY_NAMES.get(_relic.rarity_tier, "Common")).to_upper()
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.custom_minimum_size.x = TEXT_WIDTH
	rarity.add_theme_font_override("font", rarity_font)
	rarity.add_theme_font_size_override("font_size", 12)
	rarity.add_theme_color_override("font_color",
			RARITY_COLORS.get(_relic.rarity_tier, RARITY_COLORS[Relic.RarityTier.COMMON]))
	rarity.add_theme_constant_override("outline_size", 4)
	rarity.add_theme_color_override("font_outline_color", OUTLINE)
	rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_block.add_child(rarity)

	# --- description ---
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = TEXT_WIDTH
	body.add_theme_font_override("normal_font", BODY_FONT)
	# bold_font is NOT optional: overriding only normal_font makes every [b] in the colorized
	# text silently fall back to the theme's CinzelDecorative (documented trap, 2026-08-19).
	body.add_theme_font_override("bold_font", BODY_FONT)
	body.add_theme_font_size_override("normal_font_size", 18)
	body.add_theme_font_size_override("bold_font_size", 18)
	body.add_theme_color_override("default_color", CREAM)
	body.add_theme_constant_override("outline_size", 4)
	body.add_theme_color_override("font_outline_color", OUTLINE)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Power glyph sized by the house convention of font_size + 2.
	body.text = "[center]%s[/center]" % _relic.get_colorized_description(_relic.tooltip, 20)
	_column.add_child(body)

	var hint := Label.new()
	hint.text = "Click anywhere to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.x = TEXT_WIDTH
	hint.add_theme_font_override("font", BODY_FONT)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(hint)


# Reads the real wrapped height back off the column rather than modelling the wrap - the same
# approach achievement_toast.gd settled on after two attempts to predict it came out short.
func _resize_to_content() -> void:
	var height: float = maxf(_column.get_combined_minimum_size().y + PAD * 2.0, PANEL_MIN_HEIGHT)
	_panel.size = Vector2(PANEL_WIDTH, height)
	_panel.position = ((CANVAS - _panel.size) * 0.5).round()
	_panel.pivot_offset = _panel.size / 2.0


func _on_click_anywhere(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)
