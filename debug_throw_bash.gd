extends Node

# Temporary render harness for the thrown-dice BASH choreography rework (2026-07-24):
# windup -> ascent above the enemy -> face-lock hang -> downward slam. Renders a real
# fight (solo Skeleton) + the dice cluster, emits Events.dice_thrown, and lets Movie
# Maker mode save a deterministic 30fps frame sequence (fixed deltas - texture-load
# hitches can't compress the beats like real-time capture did) so the choreography
# (apex below the intent icon, face locked at hang, slam, impact, alternating scatter,
# per-die sequencing) can be inspected offline.
# Run (movie mode is REQUIRED - each engine frame advances exactly 1/30s):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_throw_bash.tscn
#       --write-movie <out_dir>/f.png --fixed-fps 30
#       --rendering-driver opengl3 --position 2000,2000
# Env:
#   THROW_BASH_MODE  = "volley" (default: 3 mixed dice), "single" (one giant die),
#                      "airland" (target-null support throw - must keep the old arc)
#   THROW_BASH_FIGHT = res:// path to a battle scene (default tier_1_crab_satyr, a wide
#                      Satyr with a neighbor - reproduces the "die sits on the body" +
#                      neighbor-overlap case from Julien's playtest video)

const CARD_RELEASE := Vector2(470, 405)  # STAGE_HOLD_CENTER, the real play origin


func _ready() -> void:
	if not OS.has_feature("movie"):
		push_error("[throw-bash] run with --write-movie <dir>/f.png --fixed-fps 30")
		get_tree().quit(1)
		return
	var mode := OS.get_environment("THROW_BASH_MODE")
	if mode == "":
		mode = "volley"

	# Keep achievements quiet while the harness pokes at rolls/dice state.
	Global.tutorial_on = true
	Global.blue_dice_max_amount = 2
	Global.blue_dice_current_amount = 2
	Global.red_dice_max_amount = 1
	Global.red_dice_current_amount = 1
	if mode == "reel":
		# Marketing capture: own every thrown type so the dice row reads "dice game"
		# and the 8-die volley below is a legal Dice Avalanche fan-out.
		for t in ["blue", "red", "evil", "giant", "green", "even", "odd", "magma"]:
			Global.set("%s_dice_max_amount" % t, 1)
			Global.set("%s_dice_current_amount" % t, 1)
		Global.blue_dice_max_amount = 2
		Global.blue_dice_current_amount = 2
		Global.thrown_dice_bonus_fight = 0
		Global.last_played_card_position = CARD_RELEASE

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(1280, 720)
	bg.modulate = Color(0.74, 0.74, 0.74)
	add_child(bg)

	var cam := Camera2D.new()
	cam.position = Vector2(639, 361)
	add_child(cam)
	cam.make_current()

	# Real player so the enemy's action picker has its "player" group target.
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(207, 426)
	add_child(player)
	player.stats = load("res://characters/warrior/warrior.tres")

	var fight_path := OS.get_environment("THROW_BASH_FIGHT")
	if fight_path == "":
		fight_path = "res://battles/tier_1_crab_satyr.tscn"
		if mode == "reel":
			# Big readable bruiser + a neighbor for context.
			fight_path = "res://battles/tier_1_machopeur_satyr.tscn"
	var fight: Node = (load(fight_path) as PackedScene).instantiate()
	add_child(fight)

	# The dice cluster (dice.gd owns the Events.dice_thrown handler) at its real spot.
	var dice_interface: Control = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	add_child(dice_interface)
	dice_interface.position = Vector2(514, 214)
	dice_interface.size = Vector2(160, 72)
	var dice: Control = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	add_child(dice)
	dice.position = Vector2(521, 294)
	dice.size = Vector2(144, 144)

	# Screen-space ui_layer the thrown dice parent to, same as battle.tscn's.
	var ui_canvas := CanvasLayer.new()
	ui_canvas.layer = 5
	add_child(ui_canvas)
	var ui_layer := Control.new()
	ui_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_to_group("ui_layer")
	ui_canvas.add_child(ui_layer)

	for i in 12:
		await get_tree().process_frame

	# Target the WIDEST enemy (the Satyr in the default fight) - that's the body the die
	# used to sit on. Others stay as neighbors so hang-clearance is visible in context.
	var enemy: Node = null
	var best_w := -1.0
	for child in fight.get_children():
		if child is Enemy:
			child.update_action()  # intent visible - the apex clamp must stay below it
			var s = child.get("sprite_2d")
			var w := 0.0
			if s is Sprite2D:
				w = (s as Sprite2D).get_rect().size.x * (child as Node2D).scale.x
			if w > best_w:
				best_w = w
				enemy = child

	for i in 6:
		await get_tree().process_frame

	# reel: stage the real play - exact-kill HP on the target, the card presented at the
	# real stage-hold spot, a beat to read it, then the volley erupts from the card.
	var reel_card = null  # untyped: .card is a script property (typed Control would not compile)
	if mode == "reel":
		# Widest-sprite pick grabs the edge-hugging Satyr here; the mid-screen Marauder
		# is the readable target (popups clipped at the screen edge on the Satyr).
		for child in fight.get_children():
			if child is Enemy and String(child.name).begins_with("Machopeur"):
				enemy = child
		var st = enemy.get("stats")
		st.max_health = 47  # == the fixed volley total below, so the LAST die kills
		st.health = 47
		reel_card = (load("res://scenes/ui/card_menu_ui.tscn") as PackedScene).instantiate()
		add_child(reel_card)
		reel_card.card = load("res://characters/warrior/cards/card_dice_avalanche.tres")
		reel_card.position = Vector2(345, 300)  # center (415,405): clears the big roll die
		reel_card.pivot_offset = Vector2(70, 105)
		reel_card.modulate.a = 0.0
		reel_card.scale = Vector2(0.9, 0.9)
		var pop := create_tween()
		pop.set_parallel(true)
		pop.tween_property(reel_card, "modulate:a", 1.0, 0.22)
		pop.tween_property(reel_card, "scale", Vector2(1.12, 1.12), 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in 34:
			await get_tree().process_frame

	var throws: Array = []
	var tail_frames := 0
	match mode:
		"single":
			throws = [{"type": "giant", "value": 12, "target": enemy}]
			tail_frames = 62
		"airland":
			throws = [{"type": "giant", "value": 9, "target": null}]
			tail_frames = 55
		"reel":
			# Marketing take: fixed values (deterministic), REAL damage through the card's
			# own _land_thrown_die (popups at impact, HP chip, hit-stop), giant 12 last as
			# the killing blow. Sum = 47 = target HP, so no mid-volley death/retarget.
			var av := [["blue", 3], ["green", 2], ["odd", 7], ["red", 5],
					["even", 8], ["magma", 4], ["evil", 6], ["giant", 12]]
			for e in av:
				throws.append({"type": e[0], "value": e[1], "target": enemy})
			var av_card: Card = load("res://characters/warrior/cards/card_dice_avalanche.tres")
			var stagger := Global.dice_throw_volley_stagger(throws.size())
			for i in throws.size():
				var entry: Dictionary = throws[i]
				av_card._land_thrown_die(get_tree(), enemy, int(entry["value"]),
						Global.DICE_THROW_FLIGHT_TIME + stagger * i,
						av_card.sound, String(entry["type"]), int(entry["value"]))
			if reel_card != null:
				var exit := create_tween()
				exit.set_parallel(true)
				exit.tween_property(reel_card, "position", Vector2(1150, 620), 0.42) \
						.set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				exit.tween_property(reel_card, "scale", Vector2(0.12, 0.12), 0.42) \
						.set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				exit.tween_property(reel_card, "modulate:a", 0.0, 0.28).set_delay(0.5)
			tail_frames = 150
		"avalanche":
			# One die of each owned type at the target - the max Dice Avalanche fan-out,
			# for checking the drumroll spacing / per-hit readability.
			var av := [["giant", 12], ["blue", 3], ["evil", 6], ["red", 5],
					["green", 2], ["even", 8], ["odd", 7], ["magma", 4]]
			for e in av:
				throws.append({"type": e[0], "value": e[1], "target": enemy})
			tail_frames = 140
		_:
			throws = [
				{"type": "giant", "value": 12, "target": enemy},
				{"type": "blue", "value": 3, "target": enemy},
				{"type": "evil", "value": 6, "target": enemy, "thud": true},
			]
			tail_frames = 80

	var emit_origin := CARD_RELEASE
	if mode == "reel":
		emit_origin = Vector2(415, 405)  # the staged card's center - dice erupt from the card
	print("[throw-bash] emitting '%s' now at engine frame %d (movie lead-in ends here)" % [mode, Engine.get_process_frames()])
	Events.dice_thrown.emit(throws, emit_origin)

	for f in tail_frames:
		await get_tree().process_frame
	print("[throw-bash] done (%s)" % mode)
	get_tree().quit()
