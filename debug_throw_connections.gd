extends Node

# Headless verification harness for the thrown-dice connections pass (2026-07-23).
# Not committed. Run:
#   "C:\Users\julie\Desktop\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64_console.exe" \
#       --headless --path . res://debug_throw_connections.tscn
# Verifies:
#   1) every touched card/relic/status script still compiles (direct loads + pool load
#      catches any _land_thrown_die call site left on the old 5-arg signature)
#   2) Global.report_thrown_die_landed increments the three counters and emits
#      Events.dice_thrown_landed with the die's type+value
#   3) Card.thrown_faces_for honors infusion face overrides (Repented/Bulky)
#   4) end-to-end: Crown and Metronome trigger off a thrown-die landing through the
#      real RelicUI wiring
# Exit code = number of failed checks.

const THROW_SCRIPTS := [
	"res://custom_resources/card.gd",
	"res://characters/warrior/cards/meteor.gd",
	"res://characters/warrior/cards/cursed_toss.gd",
	"res://characters/warrior/cards/cursed_toss_plus.gd",
	"res://characters/warrior/cards/pixie_volley.gd",
	"res://characters/warrior/cards/dice_avalanche.gd",
	"res://characters/warrior/cards/dice_avalanche_plus.gd",
	"res://characters/warrior/cards/fastball.gd",
	"res://characters/warrior/cards/fastball_plus.gd",
	"res://characters/warrior/cards/windfall.gd",
	"res://characters/warrior/cards/rampart.gd",
	"res://characters/warrior/cards/kickstart.gd",
	"res://relics/crown.gd",
	"res://relics/snake_eyes_charm.gd",
	"res://relics/hunting_bow.gd",
	"res://relics/the_one.gd",
	"res://relics/metronome.gd",
	"res://relics/house_money.gd",
	"res://statuses/status_hardened_grip.gd",
	"res://statuses/greedy.gd",
]

var _fails := 0
var _probe_hits: Array = []


func _check(label: String, ok: bool) -> void:
	if ok:
		print("PASS  ", label)
	else:
		_fails += 1
		print("FAIL  ", label)


func _on_probe(dice_type: String, value: int) -> void:
	_probe_hits.append([dice_type, value])


func _ready() -> void:
	# Suppress any achievement unlock/toast side effects while the harness pokes counters.
	Global.tutorial_on = true

	# --- 1) compile checks ---
	for path in THROW_SCRIPTS:
		var s = load(path)
		_check("compiles: " + path, s != null and s.can_instantiate())
	var pool = load("res://characters/warrior/warrior_draftable_cards.tres")
	_check("draftable pool loads (all card scripts compile)", pool != null)
	var relic_pool = load("res://treasure_relic_pool.tres")
	_check("treasure relic pool loads", relic_pool != null)

	# --- 2) central report: counters + per-die emission ---
	Global.fight_dice_rolled = 0
	Global.dice_amount_rolled_this_turn = 0
	Global.run_stat_dice_rolled = 0
	Events.dice_thrown_landed.connect(_on_probe)
	Global.report_thrown_die_landed("green", 1)
	_check("fight_dice_rolled incremented", Global.fight_dice_rolled == 1)
	_check("dice_amount_rolled_this_turn incremented", Global.dice_amount_rolled_this_turn == 1)
	_check("run_stat_dice_rolled incremented", Global.run_stat_dice_rolled == 1)
	_check("signal carried (green, 1)", _probe_hits == [["green", 1]])
	Events.dice_thrown_landed.disconnect(_on_probe)

	# --- 3) infusion-aware thrown faces ---
	Global.dice_infusions = {}
	_check("evil base faces", Card.thrown_faces_for("evil") == [0, 6, 6, 6])
	Global.dice_infusions = {"evil": "repented"}
	var repented: Array = Card.thrown_faces_for("evil")
	_check("repented evil drops the crack", not repented.has(0) and repented.has(6))
	Global.dice_infusions = {"giant": "bulky"}
	var bulky: Array = Card.thrown_faces_for("giant")
	_check("bulky giant uses override (no 1, has 12)", not bulky.has(1) and bulky.has(12))
	Global.dice_infusions = {}

	# --- 4) end-to-end relic wiring off a thrown-die landing ---
	var relic_ui_scene = load("res://scenes/relic_handler/relic_ui.tscn")

	var crown_ui: RelicUI = relic_ui_scene.instantiate()
	add_child(crown_ui)
	var crown: Relic = load("res://relics/crown.tres")
	crown_ui.relic = crown  # setter awaits ready + calls initialize_relic
	await get_tree().process_frame
	Global.fight_dice_rolled = 9
	Global.dice_type = "blue"
	Global.blue_dice_current_amount = 0
	Global.report_thrown_die_landed("blue", 3)
	_check("crown counter shows 10 after thrown landing", crown_ui.counter.text == "10")
	_check("crown granted +1 blue die off thrown landing", Global.blue_dice_current_amount == 1)
	crown.deactivate_relic(crown_ui)

	var metro_ui: RelicUI = relic_ui_scene.instantiate()
	add_child(metro_ui)
	var metro: Relic = load("res://relics/metronome.tres")
	metro_ui.relic = metro
	await get_tree().process_frame
	Global.dice_amount_rolled_this_turn = 2
	Global.roll_value = 0
	Global.report_thrown_die_landed("blue", 4)
	_check("metronome every-3rd proc off thrown landing (+2 power)", Global.roll_value == 2)
	_check("metronome counter shows 3", metro_ui.counter.text == "3")
	metro.deactivate_relic(metro_ui)

	Global.tutorial_on = false
	print("---- throw-connections harness done: %d failure(s) ----" % _fails)
	get_tree().quit(_fails)
