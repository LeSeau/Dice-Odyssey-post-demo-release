extends Node

# Movie Maker harness for the roll hop animation (juice_audit_2026-08.md P0: the main die
# now hops off its plinth, tumbles a full turn while cycling faces, and slams down on the
# result with a landing squash + ground dust). Boots the REAL battle.tscn through
# start_battle() (same recipe as debug_double_endturn.gd, minus the SubViewport - Movie
# Maker captures the main window), forces a scripted Blue sequence ending on a max roll,
# then quits.
#
# Run (frames land in the folder passed to --write-movie; keep it OUTSIDE res:// so the
# export filter never sees them):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_roll_feel.tscn \
#       --write-movie <out_dir>/f.png --fixed-fps 60 --resolution 1280x720 \
#       --rendering-driver opengl3 --position 2000,2000
#
# NOTE (documented Movie Maker trap): frames include engine boot and boot time varies per
# run - never compare frame numbers across two captures.

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
# Low, mid, dud (1: small dust, no bounce), max, then a 5 that crosses the 18-power tier
# threshold (2+5+1+6+5 = 19): covers the per-roll variation, value-scaled dust, max-roll
# celebration, the chain-pitched land thuds (5 consecutive = 5 ladder steps in the
# captured wav) and the tier-crossing ignition on the Power number.
const FORCED_ROLLS: Array[int] = [2, 5, 1, 6, 5]

# Env overrides (all optional, defaults reproduce the original capture):
#   ROLL_FORCED="6,6"     comma-separated faces to force instead of FORCED_ROLLS
#   ROLL_FACE_CHECK=0     skip the 40-roll face/value regression (long in movie mode)
#   ROLL_HITS=0           skip the two directional hit smears at the end
#   ROLL_HOLD=2.2         seconds to hold after the last roll (default 1.6)
var forced_rolls: Array[int] = []
var hands_drawn := 0


func _ready() -> void:
	# Stale uid cache guard (2026-09-08): after the Grindstone -> Forge rename done outside
	# the editor, .godot/uid_cache.bin still mapped the card's uid to the deleted path, the
	# loader trusted the uid over the pool's path=, warrior.tres failed to load and this
	# harness hung before it could quit (1 GB of Movie Maker frames). Repaired in memory.
	_repair_stale_uids(["res://characters/warrior/cards", "res://statuses", "res://relics",
			"res://characters/warrior"])

	# Mute the Music bus outright (not MusicPlayer.stop(), which left the track running in
	# the 2026-08 captures) - the wav must contain only SFX so the thud pitch ladder is
	# audible and analyzable.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)

	var battle: Battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	add_child(battle)

	var relic_handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	# HBoxContainer needs a Control ancestor or its layout collapses to zero (documented
	# harness trap).
	var host := Control.new()
	host.size = Vector2(400, 80)
	add_child(host)
	host.add_child(relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	battle.char_stats = warrior.create_instance()
	battle.relics = relic_handler
	battle.battle_stats = load(FIGHT)
	battle.act_tier = 1

	battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > 0, 15.0)
	# Let the opening hand fan/entrance settle so the capture starts from a calm frame.
	for i in 40:
		await get_tree().process_frame

	var dice: Node = battle.find_child("ActiveDice", true, false)
	if dice == null or not dice.has_method("roll_dice"):
		for child in battle.get_children():
			if child.has_method("roll_dice"):
				dice = child
				break
	if dice == null:
		push_error("[roll-feel] no dice node with roll_dice() found")
		get_tree().quit(1)
		return

	# Which animation preset to render: ROLL_STYLE=HOP|TOSS|SPIN|DROP (default HOP).
	var style_name := OS.get_environment("ROLL_STYLE").to_upper()
	if style_name != "":
		var idx: int = ["HOP", "TOSS", "SPIN", "DROP", "CALM"].find(style_name)
		if idx >= 0:
			dice.roll_style = idx
			print("[roll-feel] style = ", style_name)
		else:
			push_error("[roll-feel] unknown ROLL_STYLE '%s'" % style_name)

	forced_rolls = FORCED_ROLLS.duplicate()
	var forced_env := OS.get_environment("ROLL_FORCED")
	if forced_env != "":
		forced_rolls.clear()
		for token in forced_env.split(","):
			if token.strip_edges().is_valid_int():
				forced_rolls.append(int(token.strip_edges()))
		print("[roll-feel] forced rolls = ", forced_rolls)

	# Enough dice that the forced sequence never runs dry, regardless of relic setup.
	Global.blue_dice_current_amount = forced_rolls.size() + 2
	Global.tutorial_forced_rolls = forced_rolls.duplicate()

	for i in forced_rolls.size():
		if i == 0:
			# First roll goes through the button weld path: coil (held press), beat,
			# then launch-from-coil - the same sequence a real click produces.
			dice.coil_die()
			await get_tree().create_timer(0.45, false).timeout
		dice.roll_dice()
		# Animation is ~0.35s to landing + punch/settle; the gap between rolls also
		# exercises the "kill stale motion on re-roll" guard at a realistic pace.
		# ROLL_GAP widens it when a capture needs each landing fully isolated (comparing
		# several max rolls against each other - the crush burst runs ~0.9s).
		var gap := 1.1
		if OS.get_environment("ROLL_GAP").is_valid_float():
			gap = float(OS.get_environment("ROLL_GAP"))
		await get_tree().create_timer(gap, false).timeout

	# REGRESSION: the face shown must match the value that was actually rolled. The face
	# shuffle runs on its own tween, so a pending flip could fire AFTER the landing and
	# overwrite the settled face - the die read 3 while Power counted 1. Every roll goes
	# through the coil path here (that's what shortens the flight and opens the race).
	if OS.get_environment("ROLL_FACE_CHECK") != "0":
		await _assert_face_matches_value(dice)

	# Hold on the max-roll celebration + orb arrivals before ending the capture.
	var hold := 1.6
	if OS.get_environment("ROLL_HOLD").is_valid_float():
		hold = float(OS.get_environment("ROLL_HOLD"))
	await get_tree().create_timer(hold, false).timeout

	var hit_list: Array = [8, 18]
	if OS.get_environment("ROLL_HITS") == "0":
		hit_list = []
	# Directional hit smears: two hits (mid + heavy). Re-query and validity-check before
	# EACH hit - the first one can kill a low-HP enemy (a freed node aborted the whole
	# coroutine on the first run of this harness, leaving Movie Maker running forever).
	for dmg in hit_list:
		var target: Enemy = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.stats.health > 0:
				target = e
				break
		if target == null:
			break
		target.take_damage(dmg, Modifier.Type.DMG_TAKEN)
		await get_tree().create_timer(0.8, false).timeout

	print("[roll-feel] capture done")
	get_tree().quit(0)


# Rolls a forced value many times through the coil path and checks the texture actually
# displayed once everything settles. Fails loudly with the face/value mismatch so the
# race can't come back silently.
func _assert_face_matches_value(dice: Node) -> void:
	var display: TextureRect = dice.get_node("Panel/DiceDisplay")
	var mismatches := 0
	var checked := 0
	for i in 40:
		var want: int = [1, 2, 3, 5, 6][i % 5]
		Global.blue_dice_current_amount = 5
		Global.tutorial_forced_rolls = [want]
		# Coil first: the held press skips the wind-up, which is what pulls the flight's
		# end back under the flip schedule.
		dice.coil_die()
		await get_tree().create_timer(0.09, false).timeout
		dice.roll_dice()
		await get_tree().create_timer(0.85, false).timeout
		var path: String = display.texture.resource_path if display.texture else "<null>"
		var shown := path.get_file().get_basename().trim_prefix("blue")
		checked += 1
		if shown != str(want):
			mismatches += 1
			print("[roll-feel] FACE MISMATCH: rolled %d but showing '%s'" % [want, shown])
	if mismatches == 0:
		print("[roll-feel] FACE CHECK PASS (%d/%d rolls showed the rolled value)" % [checked, checked])
	else:
		print("[roll-feel] FACE CHECK FAIL: %d/%d mismatched" % [mismatches, checked])


# The CLI process reads .godot/uid_cache.bin, which only the EDITOR rewrites. A rename done
# outside the editor (git mv, a script) leaves the cache mapping the file's uid to its OLD
# path, and ext_resource loading trusts a known uid over its path= - so the renamed file
# "does not exist" even though the pool points at it correctly. Re-points stale entries
# from each .tres header's own uid, in memory only (never ResourceUID.save_to_cache()).
func _repair_stale_uids(dirs: Array[String]) -> void:
	for dir_path in dirs:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if not file.ends_with(".tres"):
				continue
			var path := dir_path.path_join(file)
			var header := FileAccess.get_file_as_string(path).get_slice("\n", 0)
			var uid_pos := header.find("uid=\"uid://")
			if uid_pos < 0:
				continue
			var uid_text := header.substr(uid_pos + 5).get_slice("\"", 0)
			var id := ResourceUID.text_to_id(uid_text)
			if id == ResourceUID.INVALID_ID:
				continue
			if ResourceUID.has_id(id):
				var cached := ResourceUID.get_id_path(id)
				if cached != path and not FileAccess.file_exists(cached):
					ResourceUID.set_id(id, path)
					print("[roll-feel] uid repaired: %s -> %s (cache said %s)" % [uid_text, path, cached])
			else:
				ResourceUID.add_id(id, path)


func _await_until(cond: Callable, timeout_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
