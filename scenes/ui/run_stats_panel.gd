# Shared "run stats" scoreboard - used by the end-of-run screens (Game Over panel in
# battle_over_panel.tscn, boss GG panels in battle_reward.tscn) and by the main menu's
# Load Run confirmation card. Attached as a script on a plain PanelContainer node in
# those scenes; deliberately NO class_name (a fresh class_name isn't in the editor's
# global class cache until a rescan, and this stays renderable headless right away -
# same reasoning as achievement_toast.gd).
#
# By default builds the end-of-run rows from Global.run_stat_* in _ready(), hidden
# (modulate.a = 0). Screens with different data (the Load Run card reads the SAVE
# FILE, not Global) call build_rows() with their own defs, which clears and rebuilds.
# Row def: {label, icon, value: int} gets the animated count-up; {label, icon,
# text: String} renders as-is (fade only - for values like "47 / 72" HP).
#
# The owning screen calls animate_in() when its panel is revealed: rows fade in
# staggered and every count-up number rolls from 0 with a small landing pop. Tweens
# are bound to nodes under this panel, so they keep animating on the paused tree of
# the Game Over screen (BattleOverPanel is PROCESS_MODE_ALWAYS, inherited).
extends PanelContainer

const CINZEL_BOLD := preload("res://fonts/Cinzel-Bold.otf")
const NOTO_SANS := preload("res://fonts/NotoSans-Regular.ttf")
const LUCKIEST_GUY := preload("res://fonts/LuckiestGuy-Regular.ttf")
const GEM_TEXTURE := preload("res://assets/images/rarity_gem_rare.png")

const GOLD := Color(0.941176, 0.752941, 0.25098)
const HEADER_GOLD := Color(0.858824, 0.717647, 0.278431)
const CREAM := Color(0.92549, 0.890196, 0.815686)
const OUTLINE_BROWN := Color(0.14, 0.09, 0.03)

const ROW_HEIGHT := 31.0
const REVEAL_STAGGER := 0.09
const REVEAL_FADE_TIME := 0.3
const COUNT_UP_TIME := 0.65
const VALUE_POP_SCALE := 1.25

# Icons are all existing assets - no new art. runic_bones/card_cover/charge_dice live
# at the repo root like most older icons.
const STAT_ROWS := [
	{"label": "Floor Reached", "icon": "res://assets/images/map_button_icon.png", "stat": "run_stat_highest_floor"},
	{"label": "Dice Rolled", "icon": "res://assets/images/blue6.png", "stat": "run_stat_dice_rolled"},
	{"label": "Power Generated", "icon": "res://charge_dice_icon.png", "stat": "run_stat_power_generated"},
	{"label": "Biggest Hit", "icon": "res://assets/images/swordicon.png", "stat": "run_stat_biggest_hit"},
	{"label": "Enemies Slain", "icon": "res://runic_bones.png", "stat": "run_stat_enemies_slain"},
	{"label": "Cards Played", "icon": "res://card_cover_icon.png", "stat": "run_stat_cards_played"},
	{"label": "Damage Taken", "icon": "res://assets/images/heart.png", "stat": "run_stat_damage_taken"},
]

# [{node, value_label, target}] in display order; target -1 = no count-up (text row
# or the header rule). Rebuilt by build_rows().
var _rows: Array = []
var _header: Control = null
var _margin: MarginContainer = null
var _animated := false


func _ready() -> void:
	build_rows(_global_stat_rows())


func _global_stat_rows() -> Array:
	var rows: Array = []
	for def: Dictionary in STAT_ROWS:
		rows.append({"label": def.label, "icon": def.icon, "value": int(Global.get(def.stat))})
	return rows


# Clears and (re)builds the whole scoreboard from the given row defs. Safe to call
# on a panel that already auto-built its default rows (the Load Run card does this).
func build_rows(defs: Array) -> void:
	if _margin != null:
		_margin.queue_free()
	_rows.clear()
	_header = null
	_animated = false

	add_theme_stylebox_override("panel", _panel_stylebox())

	_margin = MarginContainer.new()
	_margin.add_theme_constant_override("margin_left", 14)
	_margin.add_theme_constant_override("margin_right", 14)
	_margin.add_theme_constant_override("margin_top", 8)
	_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_margin.add_child(vbox)

	_header = _build_header()
	vbox.add_child(_header)
	vbox.add_child(_build_header_rule())

	for i in defs.size():
		var def: Dictionary = defs[i]
		vbox.add_child(_build_row(def, i))


# Kicks off the staggered reveal. Safe to call more than once (only the first runs);
# the owning screen calls this the moment its own panel entrance settles.
func animate_in() -> void:
	if _animated:
		return
	_animated = true

	var delay := 0.0
	_fade_in(_header, delay)
	delay += REVEAL_STAGGER
	for row: Dictionary in _rows:
		_fade_in(row.node, delay)
		if row.value_label != null and row.target >= 0:
			_start_count_up(row.value_label, row.target, delay + 0.1)
		delay += REVEAL_STAGGER


func _fade_in(node: Control, delay: float) -> void:
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, REVEAL_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _start_count_up(label: Label, target: int, delay: float) -> void:
	if target <= 0:
		label.text = "0"
		return
	var tween := label.create_tween()
	tween.tween_interval(delay)
	tween.tween_method(
		func(v: float) -> void: label.text = _format_number(int(round(v))),
		0.0, float(target), COUNT_UP_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_pop_value.bind(label, target))


func _pop_value(label: Label, target: int) -> void:
	label.text = _format_number(target)
	label.pivot_offset = label.size / 2.0
	var pop := label.create_tween()
	pop.tween_property(label, "scale", Vector2.ONE * VALUE_POP_SCALE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_header() -> Control:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	hbox.modulate.a = 0.0

	hbox.add_child(_build_header_gem())

	var label := Label.new()
	# Mixed case on purpose: Cinzel draws lowercase as small caps, which reads as an
	# elegant engraved title here.
	label.text = "Your Odyssey"
	label.add_theme_font_override("font", CINZEL_BOLD)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", HEADER_GOLD)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	hbox.add_child(label)

	hbox.add_child(_build_header_gem())
	return hbox


func _build_header_gem() -> TextureRect:
	var gem := TextureRect.new()
	gem.texture = GEM_TEXTURE
	gem.custom_minimum_size = Vector2(15, 15)
	gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return gem


# The gold rule under the header joins the reveal as a value-less pseudo-row (first
# stagger slot after the header itself - animate_in skips the count-up when
# value_label is null).
func _build_header_rule() -> Control:
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0, 2)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(HEADER_GOLD.r, HEADER_GOLD.g, HEADER_GOLD.b, 0.4)
	rule.add_theme_stylebox_override("panel", style)
	rule.modulate.a = 0.0
	_rows.append({"node": rule, "value_label": null, "target": -1})
	return rule


func _build_row(def: Dictionary, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.modulate.a = 0.0
	if index % 2 == 0:
		row.add_theme_stylebox_override("panel", _row_bg_stylebox())
	else:
		row.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 11)
	margin.add_child(hbox)

	var icon := TextureRect.new()
	icon.texture = load(def.icon)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = def.label
	name_label.add_theme_font_override("font", NOTO_SANS)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", CREAM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	var has_count_up: bool = def.has("value")
	var value_label := Label.new()
	value_label.text = "0" if has_count_up else str(def.text)
	value_label.add_theme_font_override("font", LUCKIEST_GUY)
	value_label.add_theme_font_size_override("font_size", 19)
	value_label.add_theme_color_override("font_color", GOLD)
	value_label.add_theme_color_override("font_outline_color", OUTLINE_BROWN)
	value_label.add_theme_constant_override("outline_size", 5)
	# Fixed width so the count-up doesn't shuffle the row's layout every frame.
	value_label.custom_minimum_size = Vector2(78, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(value_label)

	_rows.append({
		"node": row,
		"value_label": value_label,
		"target": int(def.value) if has_count_up else -1,
	})
	return row


func _panel_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(HEADER_GOLD.r, HEADER_GOLD.g, HEADER_GOLD.b, 0.45)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _row_bg_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.045)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


static func _format_number(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
