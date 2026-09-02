extends Node

# Verifies the Hex card type (junk an enemy plants in your deck) end to end.
#
# Four things are checked, and each one guards a trap that has already bitten this project:
#   A  the enum is APPENDED, so the ~219 existing cards keep their type ints
#   B  the skin wins over Celestial (junk IS Celestial, so it used to render teal + premium),
#      AND a reused CardMenuUI node resets back to a normal card - the upgrade-confirm panel
#      reuses its two preview nodes forever, so a missing reset leaks the Hex skin onto the
#      next card the player inspects
#   C  the hand glow is NEUTRAL, not HOT - a Hex used to be the brightest card in the fan
#   D  the tooltip entry exists, says the card is fight-scoped, AND fits: the panel is
#      fixed-height and clips SILENTLY, so the copy is measured against a budget derived from
#      the scene rather than eyeballed or counted in characters
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_hex_check.tscn \
#       --rendering-driver opengl3 --position 2000,2000
# Windowed on purpose: RichTextLabel content heights are wrong under --headless.

const SLANDER_PATH := "res://characters/warrior/cards/card_slander.tres"
const STRIKE_PATH := "res://characters/warrior/cards/warrior_axe_attack1.tres"
const EMANATION_PATH := "res://characters/warrior/cards/card_emanation.tres"
# Focus, not Emanation, for the glow control: Emanation is a Blessing gated Min 6, NOT
# Celestial, so it correctly reports NONE at 0 Power and proves nothing about the branch
# Hex now jumps ahead of. Focus is Celestial, ungated, and in the draftable pool.
const CELESTIAL_PATH := "res://characters/warrior/cards/card_focus.tres"

const CARD_MENU_UI := preload("res://scenes/ui/card_menu_ui.tscn")
const TOOLTIP := preload("res://scenes/ui/tooltip.tscn")

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame
	await _section_a()
	await _section_b()
	await _section_c()
	await _section_d()
	print("[hex] %d passed, %d FAILED" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _render(name: String) -> void:
	var out_dir := OS.get_environment("HEX_OUT")
	if out_dir == "":
		out_dir = "user://hex_check"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")
	print("[hex]  render -> ", name)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("[hex]  PASS  ", label, ("  " + detail) if detail != "" else "")
	else:
		_fail += 1
		print("[hex]  FAIL  ", label, "  ", detail)


# --- A: the enum and the data -----------------------------------------------------------
func _section_a() -> void:
	print("[hex] --- A: type + data")
	_check("HEX is appended (== 3)", int(Card.Type.HEX) == 3, "value=%d" % int(Card.Type.HEX))
	_check("ATTACK still 0", int(Card.Type.ATTACK) == 0)
	_check("SKILL still 1", int(Card.Type.SKILL) == 1)
	_check("BLESSING still 2", int(Card.Type.BLESSING) == 2)

	var slander: Card = load(SLANDER_PATH)
	_check("card_slander.tres loads", slander != null)
	if slander == null:
		return
	_check("Slander is a Hex", slander.type == Card.Type.HEX)
	# Celestial is load-bearing: a junk card you cannot bin without first rolling would be a
	# trap rather than a tax. The skin must beat it, not remove it.
	_check("Slander is still Celestial", slander.can_play_without_dice)
	_check("Slander still exhausts", slander.exhausts)


# --- B: the skin, plus the reuse reset ---------------------------------------------------
func _section_b() -> void:
	print("[hex] --- B: skin (CardMenuUI)")
	var host := Control.new()
	host.size = Vector2(400, 400)
	add_child(host)
	var ui := CARD_MENU_UI.instantiate()
	host.add_child(ui)
	await get_tree().process_frame

	ui.card = load(SLANDER_PATH)
	await get_tree().process_frame
	await get_tree().process_frame

	_check("frame is the Hex stylebox",
			ui.card_frame.get_theme_stylebox("panel") == ui.HEX_STYLEBOX)
	_check("banner is the Hex stylebox",
			ui.card_banner.get_theme_stylebox("panel") == ui.HEX_BANNER_STYLEBOX)
	_check("description panel is the Hex stylebox",
			ui.description_panel.get_theme_stylebox("panel") == ui.HEX_DESC_STYLEBOX)
	_check("ANY ribbon is the Hex stylebox",
			ui.requirement_panel.get_theme_stylebox("panel") == ui.HEX_REQUIREMENT_NONE_STYLEBOX)
	_check("ribbon text uses the Hex LabelSettings",
			ui.requirement_label.label_settings == ui.HEX_NO_REQUIREMENT_LABEL_SETTINGS)

	# The title goes through a DUPLICATED LabelSettings - a Label carrying one ignores
	# add_theme_color_override() outright, which is exactly how the previous session's harness
	# silently failed to test this lever at all.
	var title_settings: LabelSettings = ui.title.label_settings
	_check("title is ash, not gold",
			title_settings != null and title_settings.font_color.is_equal_approx(ui.HEX_TITLE_COLOR),
			"font_color=%s" % str(title_settings.font_color if title_settings else "<null>"))
	# Mutating the shared card_title.tres in place would repaint every title in the game.
	_check("title LabelSettings is a copy, not the shared resource",
			title_settings != ui.TITLE_LABEL_SETTINGS)
	_check("shared card_title.tres still gold",
			ui.TITLE_LABEL_SETTINGS.font_color.is_equal_approx(Color(1, 0.843137, 0)),
			"font_color=%s" % str(ui.TITLE_LABEL_SETTINGS.font_color))

	# NEGATIVE CONTROL: the same node, reused. This is the upgrade-confirm panel's exact
	# pattern, and the branch that resets a reused node to the plain look already exists only
	# because it was missed once before.
	ui.card = load(STRIKE_PATH)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("reused node drops the Hex frame",
			ui.card_frame.get_theme_stylebox("panel") == ui.BASE_STYLEBOX)
	_check("reused node drops the Hex banner",
			ui.card_banner.get_theme_stylebox("panel") == ui.NORMAL_BANNER_STYLEBOX)
	var strike_title: LabelSettings = ui.title.label_settings
	_check("reused node drops the ash title",
			strike_title != null and strike_title.font_color.is_equal_approx(Color(1, 0.843137, 0)))

	# NEGATIVE CONTROL: Blessing must be untouched by the new branch ordering.
	ui.card = load(EMANATION_PATH)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Blessing still gets the Blessing frame",
			ui.card_frame.get_theme_stylebox("panel") == ui.BLESSING_STYLEBOX)

	# Full-card render: the fan only ever shows a card's left sliver, but the deck view, the
	# card-pile views and the inspect overlay all show the whole face, so the skin has to hold
	# up at full size too.
	ui.card = load(SLANDER_PATH)
	ui.scale = Vector2(2, 2)
	# CardMenuUI pivots on its own centre, so scaling from (0,0) throws the banner and title
	# off the top of the viewport - nudge it clear before the shot.
	ui.position = Vector2(130, 170)
	await get_tree().process_frame
	await get_tree().process_frame
	_render("hex_card_full")

	host.queue_free()


# --- C: the hand glow --------------------------------------------------------------------
func _section_c() -> void:
	print("[hex] --- C: hand glow")
	# Hand has no @onready and _get_glow_state()/check_card_requirement() read only the card
	# and Global, so an off-tree instance is enough - no need to boot a whole battle, and
	# nothing here can be a false pass from a half-built scene.
	var hand := Hand.new()

	Global.ink_active = false
	Global.dice_type = "blue"
	Global.roll_value = 0

	var slander: Card = load(SLANDER_PATH)
	var focus: Card = load(CELESTIAL_PATH)
	var slander_glow: int = hand._get_glow_state(slander)
	var focus_glow: int = hand._get_glow_state(focus)

	_check("Hex glow is NEUTRAL (was HOT)",
			slander_glow == CardUI.PlayableGlow.NEUTRAL,
			"got=%s" % CardUI.PlayableGlow.keys()[slander_glow])
	# NEGATIVE CONTROL: a real Celestial card must keep the premium glow it earned. Both cards
	# take the same branch, so this is what proves the new gate is narrow rather than a blanket
	# "Celestial no longer glows".
	_check("a normal Celestial card is still HOT",
			focus_glow == CardUI.PlayableGlow.HOT,
			"got=%s" % CardUI.PlayableGlow.keys()[focus_glow])

	hand.free()


# --- D: the tooltip, measured ------------------------------------------------------------
func _section_d() -> void:
	print("[hex] --- D: tooltip fit")
	var layer := TOOLTIP.instantiate()
	add_child(layer)
	var panel: Panel = layer.get_node("Tooltip")
	await get_tree().process_frame

	var body: RichTextLabel = panel.get_node("%TooltipText")
	var title: RichTextLabel = panel.get_node("%TooltipTitle")
	var margin: MarginContainer = panel.get_node("MarginContainer")

	var heights := {}
	for key: String in ["Hex", "Blessing", "Celestial"]:
		panel.get_tooltip_content(key)
		await get_tree().process_frame
		await get_tree().process_frame
		heights[key] = body.get_content_height()
		if key == "Hex":
			_check("Hex tooltip has body text", body.text.strip_edges() != "",
					"text=%s" % body.text)
			_check("Hex tooltip states it is fight-scoped",
					body.text.to_lower().find("combat") != -1,
					"text=%s" % body.text)
			_check("Hex tooltip title is set", title.text.find("Hex") != -1,
					"title=%s" % title.text)

	var hex_h: float = heights["Hex"]
	var blessing_h: float = heights["Blessing"]
	var celestial_h: float = heights["Celestial"]
	# The ceiling is DERIVED from the scene, not copied from it: the MarginContainer box
	# minus its own top/bottom margins is all the VBox gets, and the title eats the top of
	# that. Measuring the budget this way means a future re-layout of the panel moves the
	# assertion with it instead of leaving a stale hard-coded number behind.
	panel.get_tooltip_content("Hex")
	await get_tree().process_frame
	await get_tree().process_frame
	var title_h := title.get_content_height()
	var budget := margin.size.y - float(
			margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")) - title_h
	print("[hex]  heights  Hex=%.0f Blessing=%.0f Celestial=%.0f  budget=%.0f"
			% [hex_h, blessing_h, celestial_h, budget])
	_check("Hex tooltip fits the panel (it clips in silence)",
			hex_h <= budget + 0.5,
			"hex=%.0f vs budget=%.0f" % [hex_h, budget])
	# Guard the guard: if the budget ever computes as roomy enough for anything, the check
	# above stops meaning anything. 4 lines must still be over the line.
	_check("the budget is tight enough to still catch a 4-line body",
			budget < hex_h * (4.0 / 3.0),
			"budget=%.0f vs a 4-line body ~%.0f" % [budget, hex_h * (4.0 / 3.0)])

	panel.get_tooltip_content("Hex")
	await get_tree().process_frame
	panel.show_tooltip(Vector2(60, 60))
	await get_tree().process_frame
	await get_tree().process_frame

	var out_dir := OS.get_environment("HEX_OUT")
	if out_dir == "":
		out_dir = "user://hex_check"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/hex_tooltip.png")
	print("[hex]  tooltip render -> ", out_dir)
