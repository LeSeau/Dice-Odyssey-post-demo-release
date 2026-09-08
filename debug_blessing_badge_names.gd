extends Node

# Does every card-granted status badge read as the CARD that granted it?
#
#   Godot_v4.3-stable_win64_console.exe --path . --headless res://debug_blessing_badge_names.tscn
#
# status_tooltip.gd derives the badge TITLE from status.id via capitalize() (TITLE_OVERRIDES
# is empty), so a card rename that does not move its status id leaves the badge showing the
# old name forever. This walks the draftable pool + the starting deck + every upgrade, reads
# each card's SCRIPT SOURCE to discover which statuses/*.tres it applies (rather than trusting
# a hand-written map, which is exactly the thing that drifts), and compares the derived title
# to the card's own name.
#
# GENERIC statuses are exempt on purpose: a card that grants Surge, Strength or Weak must show
# that mechanic's name, not its own. ACCEPTED holds the one card whose badge deliberately reads
# as a STATE rather than its own name. Anything else is expected to match its card.

const POOL := "res://characters/warrior/warrior_draftable_cards.tres"
const STARTER := "res://characters/warrior/warrior_starting_deck.tres"
const TOOLTIP := "res://scenes/ui/status_tooltip.gd"

# Shared mechanics whose badge deliberately keeps its own name.
const GENERIC := [
	"surge", "muscle", "strength", "true_strength", "weak", "exposed", "lucky", "unlucky",
	"depleted", "energized", "ink", "infused", "chaos", "flux", "sigil", "greedy",
]

# Deliberate divergences, each with the reason it is not a bug. A new one must be argued for
# here rather than quietly added, and anything NOT listed still fails.
const ACCEPTED := {
	# Rupture is an ATTACK, and its badge sits on the ENEMY reading "Takes 3 damage every time
	# you roll a Dice this turn" - so the past participle is the state the enemy is in, the same
	# shape as Corrode -> Exposed. Renaming the id to "rupture" would put a verb on an enemy.
	"ruptured": "Rupture",
}

var _fail := 0
var _pass := 0
var _skipped: Array[String] = []


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s   %s" % [label, detail])


func _collect(res, out: Dictionary) -> void:
	if res == null:
		return
	for c in res.cards:
		if c == null:
			continue
		out[c] = true
		if c.upgraded_version != null:
			out[c.upgraded_version] = true


# Every statuses/*.tres a card's script mentions. Reading the source is the point: it finds
# the link the same way a human would, so a future card cannot quietly escape this harness.
func _statuses_for(card) -> Array[String]:
	var found: Array[String] = []
	var script: Script = card.get_script()
	if script == null:
		return found
	var path: String = script.resource_path
	if path == "":
		return found
	var src: String = FileAccess.get_file_as_string(path)
	if src == "":
		return found
	var re := RegEx.new()
	re.compile("res://statuses/([A-Za-z0-9_]+)\\.tres")
	for m in re.search_all(src):
		var f: String = m.get_string(1)
		if not found.has(f):
			found.append(f)
	return found


func _ready() -> void:
	await get_tree().process_frame

	var tooltip_script = load(TOOLTIP)
	var overrides: Dictionary = tooltip_script.TITLE_OVERRIDES

	var cards := {}
	_collect(load(POOL), cards)
	_collect(load(STARTER), cards)

	# Deterministic order so two runs print the same thing.
	var list: Array = cards.keys()
	list.sort_custom(func(a, b): return String(a.name) < String(b.name))

	print("\n--- every card-granted status badge vs its card ---")
	var checked := 0
	for card in list:
		var base_name: String = String(card.name).trim_suffix("+")
		for file_name in _statuses_for(card):
			var st: Status = load("res://statuses/%s.tres" % file_name)
			if st == null:
				_check("%s: statuses/%s.tres loads" % [card.name, file_name], false, "missing")
				continue
			var base_id: String = st.id.trim_suffix("_plus")
			if GENERIC.has(base_id):
				_skipped.append("%s -> %s" % [card.name, base_id])
				continue
			var override: String = overrides.get(base_id, "")
			var title: String = override if override != "" else base_id.capitalize()
			var accepted: String = ACCEPTED.get(base_id, "")
			if accepted != "":
				_check("%s badge reads '%s' by design, not '%s'"
								% [card.name, title, base_name],
						accepted == base_name,
						"ACCEPTED says this belongs to '%s'" % accepted)
				continue
			checked += 1
			_check("%s badge reads '%s'" % [card.name, base_name],
					title == base_name,
					"badge says '%s' (id '%s' in %s.tres)" % [title, st.id, file_name])

	print("\n--- generic mechanic badges, exempt on purpose ---")
	for s in _skipped:
		print("  skip %s" % s)

	print("\n--- sanity ---")
	_check("the harness actually found card-granted statuses", checked >= 15, str(checked))
	_check("TITLE_OVERRIDES is empty", overrides.is_empty(), str(overrides))

	print("\n=== %d checks, %d FAIL (%d card-granted badges, %d generic skipped) ==="
			% [_pass + _fail, _fail, checked, _skipped.size()])
	get_tree().quit()
