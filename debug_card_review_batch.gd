extends Node

# Regression harness for the 2026-08-20 card review batch. Boots a real SCENE (never
# --script): without the autoloads every .tres silently loads its script properties at their
# defaults, and every assertion below would pass against nothing.
#
#   "<godot>" --path . res://debug_card_review_batch.tscn --headless

const POOL := preload("res://characters/warrior/warrior_draftable_cards.tres")
const CARDS := "res://characters/warrior/cards/"

var _pass := 0
var _fail := 0


func _ready() -> void:
	_check_pool()
	_check_cuts()
	_check_specs()
	_check_upgrades()
	_check_thrown_dice_lose_strength()
	_check_in_hand_plumbing()
	_check_status_payloads()
	print("\n==== %d passed, %d failed ====" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(label: String, condition: bool, detail := "") -> void:
	if condition:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL  %s   %s" % [label, detail])


func _card(basename: String) -> Card:
	return load(CARDS + basename + ".tres") as Card


# --- pool integrity ---------------------------------------------------------------------
func _check_pool() -> void:
	var cards: Array = POOL.cards
	_ok("pool has 87 cards", cards.size() == 87, "got %d" % cards.size())
	var ids := {}
	var nulls := 0
	for c in cards:
		if c == null:
			nulls += 1
			continue
		ids[c.id] = int(ids.get(c.id, 0)) + 1
	_ok("no null entries", nulls == 0, "%d nulls" % nulls)
	var dupes: Array = []
	for id in ids:
		if int(ids[id]) > 1:
			dupes.append(id)
	_ok("no duplicate ids", dupes.is_empty(), str(dupes))
	var upgraded_in_pool: Array = []
	for c in cards:
		if c != null and c.upgraded:
			upgraded_in_pool.append(c.id)
	_ok("no upgraded card is draftable", upgraded_in_pool.is_empty(), str(upgraded_in_pool))


func _check_cuts() -> void:
	var cut: Array[String] = ["card_cursed_toss", "card_double_or_nothing", "card_momentum", "card_repel",
			"card_bulwark", "card_reservoir", "card_fumigation", "card_counterfeit"]
	var ids := {}
	for c in POOL.cards:
		if c != null:
			ids[c.id] = true
	for id in cut:
		_ok("%s is out of the pool" % id, not ids.has(id))
		# Project convention: cut cards leave the pool, never the disk.
		_ok("%s still on disk" % id, ResourceLoader.exists(CARDS + id + ".tres"))


# --- per-card spec ----------------------------------------------------------------------
func _check_specs() -> void:
	var specs := {
		"card_compound": {"celestial": true, "rarity": 0},
		"card_compound_plus": {"celestial": true},
		"card_electrify": {"rarity": 1},
		"card_electrify_plus": {"rarity": 1},
		"card_hoard": {"rarity": 1, "celestial": false},
		"card_hoard_plus": {"celestial": true},
		"card_weighted_dice": {"rarity": 1, "req": Card.Requirement.MIN, "reqn": 6},
		"card_weighted_dice_plus": {"req": Card.Requirement.NONE},
		"card_blood_oath": {"rarity": 1},
		"card_effigy": {"rarity": 2, "req": Card.Requirement.EXACT, "reqn": 6},
		"card_effigy_plus": {"req": Card.Requirement.EXACT, "reqn": 6},
		"card_kaleidoscope": {"rarity": 2, "celestial": false},
		"card_kaleidoscope_plus": {"celestial": true},
		"card_eyepoke": {"rarity": 0},
		"card_spectrum": {"celestial": true},
		"card_spectrum_plus": {"celestial": true},
		"card_jackpot_new": {"exhausts": true},
		"card_jackpot_new_plus": {"exhausts": false},
		"card_meteor": {"req": Card.Requirement.MIN, "reqn": 5},
		"card_meteor_plus": {"req": Card.Requirement.MIN, "reqn": 5},
		"card_smash": {"req": Card.Requirement.MIN, "reqn": 10, "target": Card.Target.ALL_ENEMIES},
		"card_smash_plus": {"target": Card.Target.ALL_ENEMIES},
		"card_artillery": {"req": Card.Requirement.MIN, "reqn": 6},
		"card_artillery_plus": {"req": Card.Requirement.MIN, "reqn": 4},
		"card_loaded_dice": {"req": Card.Requirement.MIN, "reqn": 5},
		"card_loaded_dice_plus": {"req": Card.Requirement.NONE},
		"card_quicksilver": {"rarity": 2, "req": Card.Requirement.MIN, "reqn": 6},
		"card_quicksilver_plus": {"req": Card.Requirement.MIN, "reqn": 4},
		"card_second_socket": {"req": Card.Requirement.MIN, "reqn": 6},
		"card_second_socket_plus": {"req": Card.Requirement.MIN, "reqn": 4},
		"card_red_edge_plus": {"req": Card.Requirement.MIN, "reqn": 4},
		"card_socketless_red_plus": {"req": Card.Requirement.MIN, "reqn": 6},
		"card_dicelord_gift": {"req": Card.Requirement.EXACT, "reqn": 7},
		"card_dicelord_gift_plus": {"req": Card.Requirement.EXACT, "reqn": 7},
		"card_corrode": {"req": Card.Requirement.EXACT, "reqn": 7},
		"card_greed": {"rarity": 2, "req": Card.Requirement.EXACT, "reqn": 7},
		"card_greed_plus": {"req": Card.Requirement.EXACT, "reqn": 7},
		"card_cadence": {"rarity": 1, "req": Card.Requirement.MAX, "reqn": 6},
		"card_cadence_plus": {"rarity": 1, "req": Card.Requirement.MAX, "reqn": 8},
	}
	for id in specs:
		var c := _card(id)
		if c == null:
			_ok("%s loads" % id, false, "resource missing or script failed to load")
			continue
		var s: Dictionary = specs[id]
		if s.has("rarity"):
			_ok("%s rarity_tier" % id, c.rarity_tier == s["rarity"], "got %d" % c.rarity_tier)
		if s.has("req"):
			_ok("%s requirement" % id, c.requirement == s["req"], "got %d" % c.requirement)
		if s.has("reqn"):
			_ok("%s requirement_number" % id, c.requirement_number == s["reqn"],
					"got %d" % c.requirement_number)
		if s.has("celestial"):
			_ok("%s celestial" % id, c.can_play_without_dice == s["celestial"])
		if s.has("exhausts"):
			_ok("%s exhausts" % id, c.exhausts == s["exhausts"])
		if s.has("target"):
			_ok("%s target" % id, c.target == s["target"], "got %d" % c.target)

	# The three in-hand passives (and their upgrades) must all refuse the drag.
	for id in ["card_dead_weight", "card_dead_weight_plus", "card_blood_oath",
			"card_blood_oath_plus", "card_talisman", "card_talisman_plus"]:
		var c := _card(id)
		_ok("%s is unplayable" % id, c != null and c.would_no_op_now())

	# Project rule: no Celestial card resets Power. Read from source because the emit only
	# happens at play time and there is nothing to call here.
	for id in ["card_compound", "card_compound_plus", "card_spectrum", "card_spectrum_plus",
			"card_kaleidoscope_plus", "card_hoard_plus"]:
		var c := _card(id)
		if c == null or not c.can_play_without_dice:
			continue
		var src: String = FileAccess.get_file_as_string(c.get_script().resource_path)
		# The rule exists so a Celestial card cannot silently eat a bank that would otherwise
		# survive the play. A card that ENDS THE TURN is exempt by construction: the turn
		# boundary clears the Power either way, so its reset cannot cost the player anything.
		# Hoard is the only card in that shape today.
		if src.contains("Events.force_end_turn.emit()"):
			continue
		_ok("celestial %s does not reset Power" % id,
				not src.contains("Events.dice_roll_reset.emit()"))


func _check_upgrades() -> void:
	var expected: Array[String] = ["card_hoard", "card_dead_weight", "card_weighted_dice", "card_blood_oath",
			"card_effigy", "card_kaleidoscope", "card_red_edge", "card_spectrum",
			"card_talisman", "card_jackpot_new", "card_artillery", "card_loaded_dice",
			"card_quicksilver", "card_socketless_red", "card_second_socket", "card_greed",
			"card_compound", "card_electrify", "card_smash", "card_corrode", "card_meteor",
			"card_dicelord_gift", "card_cadence"]
	for id in expected:
		var c := _card(id)
		if c == null:
			_ok("%s loads" % id, false)
			continue
		_ok("%s has an upgrade" % id, c.can_be_upgraded(),
				"upgraded_version=%s upgraded=%s" % [c.upgraded_version, c.upgraded])
		if c.upgraded_version != null:
			_ok("%s+ is flagged upgraded" % id, c.upgraded_version.upgraded)
			_ok("%s+ has a distinct id" % id, c.upgraded_version.id != c.id, "both %s" % c.id)
			_ok("%s+ carries a script" % id, c.upgraded_version.get_script() != null)
			_ok("%s+ is not itself upgradable" % id, c.upgraded_version.upgraded_version == null)
	# Whole-pool invariant, not just this batch: an upgrade inherits its base's rarity. The
	# gem is cosmetic on a '+' (they are never draftable), but a mismatched one is visible in
	# the deck view and on the campfire before/after preview. Caught Earthquake+ (Common under
	# a Rare base, pre-existing) and Eyepoke+ the moment Eyepoke dropped to Common.
	for c in POOL.cards:
		if c == null or c.upgraded_version == null:
			continue
		_ok("%s+ inherits its base rarity" % c.id, c.upgraded_version.rarity_tier == c.rarity_tier,
				"base %d, + %d" % [c.rarity_tier, c.upgraded_version.rarity_tier])


# --- the mechanical change --------------------------------------------------------------
func _check_thrown_dice_lose_strength() -> void:
	# Source-reading is the honest check: a thrown die's damage is scheduled on a timer at
	# landing, so there is no synchronous value to assert against here.
	var throwers: Array[String] = ["meteor", "meteor_plus", "dice_avalanche", "dice_avalanche_plus",
			"pixie_volley", "cursed_toss", "cursed_toss_plus", "fastball", "fastball_plus"]
	for fn in throwers:
		var path: String = CARDS + fn + ".gd"
		if not FileAccess.file_exists(path):
			_ok("%s.gd exists" % fn, false)
			continue
		var src: String = FileAccess.get_file_as_string(path)
		_ok("%s throws unmodified" % fn,
				not src.contains("var die_damage := modifiers.get_modified_value"),
				"still routes the die through DMG_DEALT")
	# Meteor's OWN X damage must still take Strength - only the die lost it.
	var meteor_src: String = FileAccess.get_file_as_string(CARDS + "meteor.gd")
	_ok("Meteor's own damage still takes Strength",
			meteor_src.contains("modifiers.get_modified_value(Global.roll_value"))
	var art: String = FileAccess.get_file_as_string("res://statuses/artillery.gd")
	_ok("artillery throws unmodified", not art.contains("get_modified_value"))
	_ok("artillery draws from every type",
			art.contains("Global.DICE_TYPE_ORDER") and not art.contains("_dice_max_amount"))
	# Trebuchet is now the ONLY thrown-dice scaler - make sure that path survived.
	var card_src: String = FileAccess.get_file_as_string("res://custom_resources/card.gd")
	_ok("Trebuchet bonus still reaches throws", card_src.contains("thrown_dice_bonus_fight"))


func _check_in_hand_plumbing() -> void:
	# No Hand node here, so in_hand() is false for everything: these pin the SAFE default,
	# i.e. holding nothing grants nothing.
	_ok("no hand -> no red bonus", Global.in_hand_roll_bonus("red") == 0)
	_ok("no hand -> no damage bonus", Global.in_hand_damage_bonus() == 0)
	_ok("no hand -> no six block", Global.in_hand_six_block() == 0)
	# The id constants and the card ids must not drift apart - a typo here silently disables
	# the entire passive with no error anywhere.
	_ok("Blood Oath const", Global.IN_HAND_RED_AURA == _card("card_blood_oath").id)
	_ok("Blood Oath+ const", Global.IN_HAND_RED_AURA_PLUS == _card("card_blood_oath_plus").id)
	_ok("Dead Weight const", Global.IN_HAND_DEAD_WEIGHT == _card("card_dead_weight").id)
	_ok("Dead Weight+ const", Global.IN_HAND_DEAD_WEIGHT_PLUS == _card("card_dead_weight_plus").id)
	_ok("Talisman const", Global.IN_HAND_TALISMAN == _card("card_talisman").id)
	_ok("Talisman+ const", Global.IN_HAND_TALISMAN_PLUS == _card("card_talisman_plus").id)
	# Talisman no longer edits face sets - that job moved to the sixes payoff.
	var faces: Array = Global.current_face_values("blue")
	_ok("blue keeps all six faces", faces.size() == 6, str(faces))


func _check_status_payloads() -> void:
	var exposed: Status = load("res://statuses/exposed.tres")
	_ok("Exposed stacks by DURATION", exposed.stack_type == Status.StackType.DURATION,
			"stack_type=%d" % exposed.stack_type)
	_ok("Exposed magnitude is a flat 50%", ExposedStatus.MODIFIER == 0.5,
			"got %s" % ExposedStatus.MODIFIER)
	var eff: Status = load("res://statuses/effigy.tres")
	var eff_p: Status = load("res://statuses/effigy_plus.tres")
	_ok("Effigy hits for 5", eff.stacks == 5, "got %d" % eff.stacks)
	_ok("Effigy+ hits for 8", eff_p.stacks == 8, "got %d" % eff_p.stacks)
	_ok("Effigy badges hide the payload", eff.stack_type == Status.StackType.NONE
			and eff_p.stack_type == Status.StackType.NONE)
	var gift: Status = load("res://statuses/status_dicelord_gift.tres")
	var gift_p: Status = load("res://statuses/status_dicelord_gift_plus.tres")
	_ok("Gift charges 1", gift.stacks == 1, "got %d" % gift.stacks)
	_ok("Gift+ charges 2", gift_p.stacks == 2, "got %d" % gift_p.stacks)
	_ok("socketless_red_plus status exists",
			ResourceLoader.exists("res://statuses/status_socketless_red_plus.tres"))
