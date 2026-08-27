extends Node

# Bake-off harness for the hit-slash rework (2026-08-26). Julien on the shipped slash:
# "too fast, we can't really see it" - he likes the dice-type colour and the
# damage-scaled intensity, dislikes the animation itself.
#
# Renders a REAL fight and drives real damage through DamageEffect (so hit-stop, camera
# shake/punch, popups and SFX all behave exactly as in game - the freeze is half the
# problem being judged, so faking it would invalidate the board), then lets Movie Maker
# save a deterministic 30fps frame sequence per style.
#
# Run (movie mode REQUIRED - each engine frame is exactly 1/30s of unscaled time, so the
# hit-stop stretch shows up honestly as extra frames):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_slash_variants.tscn \
#       --write-movie <out_dir>/f.png --fixed-fps 30 \
#       --rendering-driver opengl3 --resolution 1280x720 --position 2000,2000
#
# Env:
#   SLASH_STYLE   = current | crescent | wound | flurry      (default current)
#   SLASH_DICE    = blue | magma | red | green | ...          (default blue)
#   SLASH_FIGHT   = res:// path to a battle scene             (default solo Marauder)
#   SLASH_DAMAGES = comma list of hits to land                (default 5,12,22)
#   SLASH_GAP     = frames between hits                       (default 62)

const STYLE_BY_NAME := {
	"current": 0,
	"crescent": 1,
	"wound": 2,
	"flurry": 3,
}
const HIT_SOUND := preload("res://art/slash.ogg")


func _ready() -> void:
	if not OS.has_feature("movie"):
		push_error("[slash] run with --write-movie <dir>/f.png --fixed-fps 30")
		get_tree().quit(1)
		return

	# The music bed makes the captured wav unreadable and MusicPlayer.stop() alone is not
	# enough (documented in CLAUDE.md) - mute the bus outright.
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, true)

	var style_name := OS.get_environment("SLASH_STYLE").to_lower()
	if style_name == "":
		style_name = "current"
	var style: int = STYLE_BY_NAME.get(style_name, 0)
	Enemy.slash_style = style

	var dice := OS.get_environment("SLASH_DICE")
	if dice == "":
		dice = "blue"
	Global.dice_type = dice
	# Keep achievement toasts out of the frame while the harness pokes at damage.
	Global.tutorial_on = true
	Global.berserker_boost_active = false

	var gap := 62
	if OS.get_environment("SLASH_GAP") != "":
		gap = int(OS.get_environment("SLASH_GAP"))

	var damages: Array[int] = []
	var dmg_env := OS.get_environment("SLASH_DAMAGES")
	if dmg_env == "":
		dmg_env = "5,12,22"
	for part in dmg_env.split(","):
		var s := String(part).strip_edges()
		if s != "":
			damages.append(int(s))

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(1280, 720)
	bg.modulate = Color(0.74, 0.74, 0.74)
	add_child(bg)

	# Real battle camera (script + "camera" group), so DamageEffect's shake and big-hit
	# punch_zoom actually fire. Without the group they silently no-op and the capture
	# would be judging a calmer scene than the game shows.
	var cam: Camera2D = Camera2D.new()
	cam.set_script(load("res://scenes/battle/camera_2d.gd"))
	cam.position = Vector2(639, 361)
	cam.add_to_group("camera")
	add_child(cam)
	cam.make_current()

	# Real player so the enemy AI's action picker has its "player" group target.
	var player: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(207, 426)
	add_child(player)
	player.stats = load("res://characters/warrior/warrior.tres")

	var fight_path := OS.get_environment("SLASH_FIGHT")
	if fight_path == "":
		fight_path = "res://battles/tier_0_machopeur.tscn"
	var fight: Node = (load(fight_path) as PackedScene).instantiate()
	add_child(fight)

	# The dice cluster at its real spot - the slash is tinted by the active dice type, so
	# the die that "caused" it has to be on screen for the colour link to be judgeable.
	var dice_interface: Control = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	add_child(dice_interface)
	dice_interface.position = Vector2(514, 214)
	dice_interface.size = Vector2(160, 72)
	var die: Control = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	add_child(die)
	die.position = Vector2(521, 294)
	die.size = Vector2(144, 144)

	for i in 14:
		await get_tree().process_frame

	# Widest body = the readable one to slash.
	var enemy: Node = null
	var best_w := -1.0
	for child in fight.get_children():
		if child is Enemy:
			child.update_action()
			var s = child.get("sprite_2d")
			var w := 0.0
			if s is Sprite2D:
				w = (s as Sprite2D).get_rect().size.x * (child as Node2D).scale.x
			if w > best_w:
				best_w = w
				enemy = child
	if enemy == null:
		push_error("[slash] no Enemy in %s" % fight_path)
		get_tree().quit(1)
		return

	# Fat HP pool so no hit in the ladder can kill the body mid-capture: a freed target
	# would abort the sequence AND leave Movie Maker writing frames forever.
	var st = enemy.get("stats")
	st.max_health = 999
	st.health = 999

	for i in 10:
		await get_tree().process_frame

	print("[slash] style=%s dice=%s fight=%s damages=%s (lead-in ends frame %d)"
			% [style_name, dice, fight_path, str(damages), Engine.get_process_frames()])

	for idx in damages.size():
		if not is_instance_valid(enemy):
			break
		var dmg: int = damages[idx]
		# Re-assert every hit: the dice cluster writes Global.dice_type during its own
		# init, AFTER _ready() here, so setting it once up front silently loses the
		# override and every blade renders in the default blue no matter what SLASH_DICE
		# says. Caught by measuring the added-light hue, not by eye.
		Global.dice_type = dice
		print("[slash]   hit %d = %d dmg at frame %d (dice_type=%s)"
				% [idx + 1, dmg, Engine.get_process_frames(), Global.dice_type])
		var eff := DamageEffect.new()
		eff.amount = dmg
		eff.sound = HIT_SOUND
		var targets: Array[Node] = [enemy]
		eff.execute(targets)
		for f in gap:
			await get_tree().process_frame

	for f in 40:
		await get_tree().process_frame
	print("[slash] done (%s)" % style_name)
	get_tree().quit()
