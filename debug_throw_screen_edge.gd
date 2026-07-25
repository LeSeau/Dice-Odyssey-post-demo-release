extends Node

# Render harness for the 2026-07-25 throw fixes:
#   (a) releasing a Throw card high on the screen flung the die off the top edge
#       ("the dice goes up & you don't see it") - now the origin is clamped into frame;
#   (b) Double or Nothing's coin is bigger and tossed ABOVE THE ENEMY instead of out of
#       the played card.
# Movie Maker mode is REQUIRED (fixed 1/30s deltas - real-time capture compresses the
# beats when texture loads hitch; see CLAUDE.md):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_throw_screen_edge.tscn
#       --write-movie <out_dir>/f.png --fixed-fps 30 --resolution 1280x720
#       --rendering-driver opengl3 --position 2000,2000
# Env EDGE_MODE = "high_airland" (default) | "high_enemy" | "coin" | "normal_airland"
# Env EDGE_RELEASE_Y = release height to simulate (default 150 - "the higher part of the
#     screen", where a dragged card can legitimately be let go).

const RELEASE_X := 640.0


func _ready() -> void:
	if not OS.has_feature("movie"):
		push_error("[edge] run with --write-movie <dir>/f.png --fixed-fps 30 --resolution 1280x720")
		get_tree().quit(1)
		return
	var mode := OS.get_environment("EDGE_MODE")
	if mode == "":
		mode = "high_airland"
	var release_y := 150.0
	if OS.get_environment("EDGE_RELEASE_Y") != "":
		release_y = float(OS.get_environment("EDGE_RELEASE_Y"))

	Global.tutorial_on = true
	Global.blue_dice_max_amount = 2
	Global.blue_dice_current_amount = 2

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

	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(207, 426)
	add_child(player)
	player.stats = load("res://characters/warrior/warrior.tres")

	var fight_path := OS.get_environment("EDGE_FIGHT")
	if fight_path == "":
		fight_path = "res://battles/tier_1_machopeur_satyr.tscn"
	var fight: Node = (load(fight_path) as PackedScene).instantiate()
	add_child(fight)

	var dice_interface: Control = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	add_child(dice_interface)
	dice_interface.position = Vector2(514, 214)
	dice_interface.size = Vector2(160, 72)
	var dice: Control = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	add_child(dice)
	dice.position = Vector2(521, 294)
	dice.size = Vector2(144, 144)

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

	for i in 6:
		await get_tree().process_frame

	# Numeric before/after for the clamp, so the fix is auditable without eyeballing frames.
	var raw := Vector2(RELEASE_X, release_y)
	var clamped: Vector2 = dice.call("_clamp_throw_origin", raw)
	print("[edge] release=%s -> clamped=%s" % [str(raw), str(clamped)])
	print("[edge]   OLD air-land hover y = %.1f (die top ~%.1f; <0 = off screen)"
			% [raw.y - 160.0, raw.y - 160.0 - 36.0])
	print("[edge]   NEW air-land hover y = %.1f (die top ~%.1f)"
			% [maxf(clamped.y - 160.0, 70.0), maxf(clamped.y - 160.0, 70.0) - 36.0])
	if enemy != null:
		var anchor: Vector2 = dice.call("_coin_flip_anchor", enemy, clamped)
		print("[edge]   coin anchor = %s (apex top ~%.1f)" % [str(anchor), anchor.y - 110.0 - 54.0])

	var tail := 70
	print("[edge] emitting '%s' now (movie lead-in frames end here)" % mode)
	match mode:
		"coin":
			Events.coin_flip.emit(true, raw, enemy)
			tail = 46
		"high_enemy":
			Events.dice_thrown.emit([{"type": "giant", "value": 12, "target": enemy}], raw)
			tail = 62
		"normal_airland":
			Events.dice_thrown.emit([{"type": "giant", "value": 9, "target": null}], Vector2(470, 405))
			tail = 62
		_:
			Events.dice_thrown.emit([{"type": "giant", "value": 9, "target": null}], raw)
			tail = 62

	for f in tail:
		await get_tree().process_frame
	print("[edge] done (%s)" % mode)
	get_tree().quit()
