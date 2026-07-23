extends Node

# Verification harness for the INTEGRATED idle sway (2026-07-23): renders real battle
# scenes (bg_audit-style, so enemy.gd/player.gd configure the sway materials exactly as
# in-game) and captures a frame sequence by driving the shader's manual_time override.
# Per-enemy phase/speed jitter stays live, so the captures also prove desync.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_idle_ingame.tscn \
#       --rendering-driver opengl3 --position 2000,2000
# Env: IDLE_INGAME_OUT = absolute output dir (falls back to user://idle_ingame)

const VIEW := Vector2i(1280, 720)
const FPS := 10
const SECONDS := 4.0
const BG := "res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png"
const FIGHTS := [
	"res://battles/tier_1_machopeur_satyr.tscn",  # armored + organic + hero
	"res://battles/tier_0_octopus_3.tscn",          # small octopus = floater
	# tier_0_bigger_octopus_2 verifies the bigger octopus stays GROUNDED (organic).
]

var _out := ""
var _bg_material: Material


func _ready() -> void:
	_out = OS.get_environment("IDLE_INGAME_OUT")
	if _out == "":
		_out = "user://idle_ingame"
	DirAccess.make_dir_recursive_absolute(_out)

	var battle := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	_bg_material = battle.get_node("Background").material
	battle.free()

	for fight_path in FIGHTS:
		await _render(fight_path)
	print("[idle-ingame] done -> ", _out)
	get_tree().quit()


func _render(fight_path: String) -> void:
	var fight_name := fight_path.get_file().get_basename()

	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = load(BG)
	bg.material = _bg_material
	vp.add_child(bg)

	var cam := Camera2D.new()
	cam.position = Vector2(639, 361)
	vp.add_child(cam)
	cam.make_current()

	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(207, 426)
	vp.add_child(player)
	player.stats = load("res://characters/warrior/warrior.tres")

	var fight: Node = (load(fight_path) as PackedScene).instantiate()
	vp.add_child(fight)

	for i in 8:
		await get_tree().process_frame

	# The real, enemy.gd-configured materials - drive their manual_time uniform.
	var materials: Array = []
	var player_mat: ShaderMaterial = player.get_node("SpriteRoot/Sprite2D").material
	if player_mat:
		materials.append(player_mat)
	var enemies: Array = []
	for child in fight.get_children():
		if child is Enemy and not child.is_queued_for_deletion():
			enemies.append(child)
			var m: ShaderMaterial = child.sprite_2d.material
			if m:
				materials.append(m)
	print("[idle-ingame] %s: %d sway materials live" % [fight_name, materials.size()])

	var frames := int(round(SECONDS * FPS))
	for f in frames:
		var t := float(f) / float(FPS)
		for m in materials:
			m.set_shader_parameter("manual_time", t)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(_out.path_join("%s_%03d.png" % [fight_name, f]))

	# Target-highlight regression check: outline must trace the DISPLACED silhouette.
	if not enemies.is_empty():
		enemies[0].set_target_highlight(true)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(_out.path_join("%s_highlight.png" % fight_name))
		enemies[0].set_target_highlight(false)

	print("[idle-ingame] rendered ", fight_name)
	vp.queue_free()
	await get_tree().process_frame
