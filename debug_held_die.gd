extends Node

# Held-die harness (2026-08-27). Two jobs, split by HELD_DIE_MODE:
#
#   render (default) - real combat composition (bg + battle camera + Player + a fight + the
#     dice cluster) driven through Movie Maker, so the die's tint, its seam with the body and
#     the attack thrust are judged at true on-screen size against the art they ship next to.
#     Timeline: rest on blue -> attack punch -> switch to magma (retune) -> attack punch.
#
#   dim - boots the REAL battle.tscn and asserts the enemy-turn dimming of the player's
#     action UI, since that lives on battle.gd and needs its signal wiring. Headless.
#
# Run (render):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_held_die.tscn \
#       --write-movie held_die_frames/f.png --fixed-fps 30 \
#       --rendering-driver opengl3 --resolution 1280x720 --position 2000,2000
# Run (dim):
#   HELD_DIE_MODE=dim Godot_v4.3-stable_win64_console.exe --headless --path . \
#       res://debug_held_die.tscn

const FIGHT := "res://battles/tier_0_machopeur.tscn"


func _ready() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, true)
	Global.tutorial_on = true  # keep achievement toasts out of frame

	if OS.get_environment("HELD_DIE_MODE").to_lower() == "dim":
		await _run_dim_checks()
	else:
		await _run_render()


# --- render ---------------------------------------------------------------------------
func _run_render() -> void:
	if not OS.has_feature("movie"):
		push_error("[held_die] run with --write-movie <dir>/f.png --fixed-fps 30")
		get_tree().quit(1)
		return

	Global.dice_type = "blue"

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(1280, 720)
	bg.modulate = Color(0.74, 0.74, 0.74)
	add_child(bg)

	var cam := Camera2D.new()
	cam.set_script(load("res://scenes/battle/camera_2d.gd"))
	cam.position = Vector2(639, 361)
	cam.add_to_group("camera")
	add_child(cam)
	cam.make_current()

	var player: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(207, 426)
	add_child(player)
	player.stats = load("res://characters/warrior/warrior.tres")

	var fight: Node = (load(FIGHT) as PackedScene).instantiate()
	add_child(fight)

	var dice_interface: Control = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	add_child(dice_interface)
	dice_interface.position = Vector2(514, 214)
	dice_interface.size = Vector2(160, 72)
	var die: Control = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	add_child(die)
	die.position = Vector2(521, 294)
	die.size = Vector2(144, 144)

	for i in 20:
		await get_tree().process_frame

	# The dice cluster writes Global.dice_type during its own init, AFTER this _ready ran, so
	# the type has to be re-asserted here or the hero's die would be tinted from whatever the
	# cluster settled on rather than what this harness is trying to show.
	_set_type(player, "blue")
	await _frames(38)

	_attack(player)
	await _frames(52)

	_set_type(player, "magma")
	await _frames(52)

	_attack(player)
	await _frames(52)

	get_tree().quit()


func _set_type(player: Node, type: String) -> void:
	Global.dice_type = type
	Events.active_dice_changed.emit(type)
	print("[held_die] type -> %s" % type)


func _attack(player: Node) -> void:
	# Straight through the real entry point rather than emitting card_played, so the harness
	# exercises the same call the card funnel makes.
	player.call("punch_held_die", 1.0)
	print("[held_die] attack punch")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- dim checks -----------------------------------------------------------------------
func _run_dim_checks() -> void:
	var battle: Node = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	# battle_stats takes the fight's .tres, NOT its .tscn - handing it the PackedScene kills
	# _ready silently and the harness then hangs forever waiting on a scene that never ran.
	battle.battle_stats = load("res://battles/tier_0_machopeur.tres")
	add_child(battle)
	for i in 30:
		await get_tree().process_frame

	var pass_count := 0
	var fail_count := 0

	var roots := {
		"ActiveDice": battle.get_node_or_null("ActiveDice"),
		"DiceInterface": battle.get_node_or_null("DiceInterface"),
	}
	for name in roots:
		if roots[name] == null:
			print("FAIL  %s missing from battle.tscn" % name)
			fail_count += 1
		else:
			print("ok    %s found" % name)
			pass_count += 1
	if fail_count > 0:
		_report(pass_count, fail_count)
		return

	for name in roots:
		var m: Color = roots[name].modulate
		if is_equal_approx(m.r, 1.0):
			print("ok    %s starts undimmed (%.2f)" % [name, m.r])
			pass_count += 1
		else:
			print("FAIL  %s starts at %.2f, expected 1.00" % [name, m.r])
			fail_count += 1

	Events.player_turn_ended.emit()
	for i in 30:
		await get_tree().process_frame
	for name in roots:
		var m: Color = roots[name].modulate
		if m.r < 0.75:
			print("ok    %s dimmed on enemy turn (%.2f)" % [name, m.r])
			pass_count += 1
		else:
			print("FAIL  %s still bright on enemy turn (%.2f)" % [name, m.r])
			fail_count += 1

	Events.player_turn_started.emit()
	for i in 30:
		await get_tree().process_frame
	for name in roots:
		var m: Color = roots[name].modulate
		if m.r > 0.95:
			print("ok    %s restored on player turn (%.2f)" % [name, m.r])
			pass_count += 1
		else:
			print("FAIL  %s not restored (%.2f)" % [name, m.r])
			fail_count += 1

	# The hero's die must survive a real battle boot: exercised here because the render mode
	# builds a lighter composition that would not catch a Player wiring break.
	var player := battle.get_node_or_null("Player")
	if player == null:
		print("FAIL  Player missing")
		fail_count += 1
	else:
		var held := player.get_node_or_null("SpriteRoot/HeldDiePivot/HeldDie")
		if held == null:
			print("FAIL  held die not built")
			fail_count += 1
		else:
			print("ok    held die built, modulate %s" % str(held.modulate))
			pass_count += 1

	_report(pass_count, fail_count)


func _report(pass_count: int, fail_count: int) -> void:
	print("\n[held_die] %d passed, %d failed" % [pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)
