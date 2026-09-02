extends Node

# Renders candidate PREJUDICE card palettes inside a REAL hand fan.
#
# Why a real fan and not a card side-by-side board: Hand has separation = -35 on a 140px card,
# so every card shows only its left 105px. The banner, the title and the left/top frame border
# are the only things a player actually reads at a glance - a palette that separates nicely on
# an inspect screen can still vanish in the fan. This is the judgement shot.
#
# Each candidate skins the three panels a real type-skin owns (frame / banner / description),
# built in code from the shipped normal stylebox so nothing on disk is touched.
#
# Run:
#   PREJ_OUT=<dir> Godot_v4.3-stable_win64_console.exe --path . res://debug_prejudice_palette.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const BASE_STYLEBOX := preload("res://scenes/card_ui/card_ui_normal.tres")
const BASE_BANNER := preload("res://scenes/card_ui/card_banner.tres")
const BASE_DESC := preload("res://scenes/card_ui/card_ui_description_panel_normal.tres")

const GOLD := Color(0.788235, 0.635294, 0.152941)

# bg / border / desc-outline. Candidates differ on TWO axes deliberately: hue, and whether the
# gold border survives - the border is the one mark every shipped card type shares, so dropping
# it is the loudest signal available, and A vs A_GOLD isolates whether it reads or looks broken.
const CANDIDATES := {
	"A_ash_iron": {
		"bg": Color(0.153, 0.176, 0.161),
		"border": Color(0.420, 0.443, 0.420),
		"outline": Color(0.075, 0.086, 0.078),
		"label": "A - ash body, dull iron border (no gold)",
	},
	"A_ash_gold": {
		"bg": Color(0.153, 0.176, 0.161),
		"border": GOLD,
		"outline": Color(0.075, 0.086, 0.078),
		"label": "A2 - ash body, gold border kept (convention-obeying)",
	},
	"B_verdigris": {
		"bg": Color(0.129, 0.180, 0.157),
		"border": Color(0.400, 0.545, 0.451),
		"outline": Color(0.063, 0.090, 0.078),
		"label": "B - corroded green, oxidised copper border",
	},
	"C_bruise": {
		"bg": Color(0.165, 0.153, 0.212),
		"border": GOLD,
		"outline": Color(0.082, 0.075, 0.106),
		"label": "C - cold bruise indigo, gold border (nearest to Blessing)",
	},
}

const SHIPPED := "SHIPPED_baseline"
const FULL := "D_full_treatment"

# Desaturating the art needs a shader - modulate only multiplies, it cannot pull chroma out.
const DESAT_CODE := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.85;
uniform float darken : hint_range(0.0, 1.0) = 0.72;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(g), amount) * darken;
	COLOR = c * COLOR;
}
"""

var _battle: Battle
var _viewport: SubViewport
var _out_dir := ""
var hands_drawn := 0


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	_out_dir = OS.get_environment("PREJ_OUT")
	if _out_dir == "":
		_out_dir = "user://prejudice_palette"
	DirAccess.make_dir_recursive_absolute(_out_dir)

	await _boot()

	# Baseline first: the same five cards with Slander left in the shipped normal skin, so the
	# candidates are judged against what the card looks like TODAY, not against nothing.
	await _shoot(SHIPPED, {})
	for key: String in CANDIDATES:
		await _shoot(key, CANDIDATES[key])
	await _shoot(FULL, CANDIDATES["A_ash_iron"])

	print("[prejudice] done -> ", _out_dir)
	get_tree().quit()


func _boot() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	add_child(_viewport)

	_battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	_viewport.add_child(_battle)

	var relic_handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	# Documented harness trap: an HBoxContainer with no Control ancestor collapses to zero size.
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	_battle.char_stats = warrior.create_instance()
	_battle.relics = relic_handler
	_battle.battle_stats = load("res://battles/tier_1_slanderers.tres")
	_battle.act_tier = 1
	relic_handler.add_relic(warrior.starting_relic)

	var before := hands_drawn
	_battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > before, 15.0)


# Rebuild the hand every shot so a candidate cannot inherit the previous one's overrides.
func _stage_hand() -> CardUI:
	var hand: Hand = _battle.battle_ui.hand
	for child in hand.get_children():
		hand.remove_child(child)
		child.queue_free()
	await get_tree().process_frame

	var cards: Array[Card] = [
		load("res://characters/warrior/cards/warrior_axe_attack1.tres"),
		load("res://characters/warrior/cards/card_emanation.tres"),
		load("res://characters/warrior/cards/card_slander.tres"),
		load("res://characters/warrior/cards/warrior_block1.tres"),
		load("res://characters/warrior/cards/card_recombobulate.tres"),
	]
	var slander_ui: CardUI = null
	for card: Card in cards:
		if card == null:
			continue
		hand.add_card(card)
	await get_tree().process_frame
	await get_tree().process_frame
	for child in hand.get_children():
		var ui := child as CardUI
		if ui != null and ui.card != null and ui.card.id == "card_slander":
			slander_ui = ui
	return slander_ui


func _shoot(key: String, palette: Dictionary) -> void:
	var slander_ui := await _stage_hand()
	if slander_ui == null:
		print("[prejudice] SKIP ", key, " - no Slander CardUI in hand")
		return

	if not palette.is_empty():
		_apply(slander_ui, palette)
	if key == FULL:
		_apply_full(slander_ui, palette)

	# Let the fan settle: add_card defers _update_card_positions, and the entrance tween on a
	# freshly dealt card still has alpha to climb.
	await _wait_seconds(1.2)

	var img := _viewport.get_texture().get_image()
	img.save_png(_out_dir + "/" + key + ".png")
	print("[prejudice] rendered ", key)


func _apply(ui: CardUI, palette: Dictionary) -> void:
	var frame := BASE_STYLEBOX.duplicate() as StyleBoxFlat
	frame.bg_color = palette["bg"]
	frame.border_color = palette["border"]

	var banner := BASE_BANNER.duplicate() as StyleBoxFlat
	banner.bg_color = palette["bg"]
	banner.border_color = palette["border"]

	var desc := BASE_DESC.duplicate() as StyleBoxFlat
	desc.bg_color = palette["bg"]

	ui.card_frame.add_theme_stylebox_override("panel", frame)
	ui.card_banner.add_theme_stylebox_override("panel", banner)
	ui.description_panel.add_theme_stylebox_override("panel", desc)
	ui.description.add_theme_color_override("font_outline_color", palette["outline"])
	# The documented trap: set_playable_visual() caches the resting frame stylebox, so without
	# this resync the card snaps back to the wine frame the moment anything re-styles it.
	ui._base_frame_stylebox = frame


# The three levers that actually occupy pixels in the fan, on top of the frame palette:
# the requirement ribbon (a full-width bar), the art (it fills the visible band), and the
# glow state (can_play_without_dice currently forces HOT, the brightest state in the game).
func _apply_full(ui: CardUI, palette: Dictionary) -> void:
	var ribbon := BASE_STYLEBOX.duplicate() as StyleBoxFlat
	ribbon.bg_color = (palette["bg"] as Color).lightened(0.06)
	ribbon.border_color = palette["border"]
	ui.requirement_panel.add_theme_stylebox_override("panel", ribbon)
	ui.requirement_label.add_theme_color_override("font_color", Color(0.62, 0.65, 0.62))

	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = DESAT_CODE
	mat.shader = sh
	mat.set_shader_parameter("amount", 0.85)
	mat.set_shader_parameter("darken", 0.72)
	ui.icon.material = mat

	ui.title.add_theme_color_override("font_color", Color(0.66, 0.69, 0.66))
	# drop the HOT glow: no expanded border, no bright rim
	var calm := ui.card_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	calm.border_width_left = 2
	calm.border_width_top = 2
	calm.border_width_right = 2
	calm.border_width_bottom = 2
	calm.expand_margin_left = 2.0
	calm.expand_margin_top = 2.0
	calm.expand_margin_right = 2.0
	calm.expand_margin_bottom = 2.0
	ui.card_frame.add_theme_stylebox_override("panel", calm)
	ui._base_frame_stylebox = calm


func _wait_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _await_until(cond: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
