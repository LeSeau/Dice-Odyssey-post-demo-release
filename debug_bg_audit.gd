extends Node

# Temporary render harness for the background/enemy-positioning audit (2026-07-15).
# Renders every pool fight over each background it can actually appear on in a run
# (act 1 + recycled act 2, per run.gd's ACT2_SOURCE_TIER) and saves PNGs plus a JSON
# of engine-computed sprite/UI rects for numeric checks.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_bg_audit.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Env:
#   BG_AUDIT_OUT  = absolute output dir (falls back to user://bg_audit)
#   BG_AUDIT_ONLY = optional substring filter on the fight scene name (quick probes)

const VIEW := Vector2i(1280, 720)

const BG_PATHS := {
	"act1_hallway": "res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png",
	"act2_hallway": "res://assets/backgrounds/combat_bg_act2_hallway_arcane_library.png",
	"act1_elite": "res://assets/backgrounds/combat_bg_act1_elite_blue_throne_hall.png",
	"act2_elite": "res://assets/backgrounds/combat_bg_act2_elite_cool_lava.png",
	"act1_boss": "res://assets/backgrounds/combat_bg_act1_boss_coastal_storm.png",
	"act2_boss": "res://assets/backgrounds/combat_bg_act2_boss_coastal_mist.png",
}

# battle_tier 0 fights only ever run in act 1's hallway; tiers 1-2 are also recycled
# into act 2's hallway; elites/boss reuse themselves in act 2 with their own looks.
const FIGHTS_T0 := [
	"res://battles/tier_0_crab.tscn",
	"res://battles/tutorial_fight.tscn",
	"res://battles/tier_0_plant.tscn",
	"res://battles/tier_0_machopeur.tscn",
	"res://battles/tier_0_octopus_3.tscn",
	"res://battles/tier_0_satyrs_3.tscn",
	"res://battles/tier_0_octopus_1_satyrs_2.tscn",
	"res://battles/tier_0_octopus_2_satyr_1.tscn",
	"res://battles/tier_0_satyrs_1_octopus_2.tscn",
	"res://battles/tier_0_satyrs_2_octopus_1.tscn",
	"res://battles/tier_0_dice_mimic.tscn",
	# The three double-big comps (bigger_octopus_2, bigger_satyrs_2,
	# bigger_satyr_octopus) were cut from the tier-0 pool on 2026-09-01. Their scenes
	# are still on disk but nothing can draw them, so auditing them is noise.
]
const FIGHTS_T12 := [
	"res://battles/tier_1_oculus_goblin.tscn",
	"res://battles/tier_1_defender.tscn",
	"res://battles/tier_1_sigil_slug.tscn",
	"res://battles/tier_1_lurker.tscn",
	"res://battles/tier_1_plant_octopus.tscn",
	"res://battles/tier_1_machopeur_satyr.tscn",
	"res://battles/tier_1_plant_goblin.tscn",
	"res://battles/tier_1_crab_satyr.tscn",
	"res://battles/tier_1_machopeur_octopus.tscn",
	"res://battles/tier_1_octopus_2_satyrs_2.tscn",
	"res://battles/tier_2_medusa.tscn",
	"res://battles/tier_2_hound.tscn",
	"res://battles/tier_2_plant_crab.tscn",
	"res://battles/tier_2_vortex.tscn",
	"res://battles/tier_1_lurker_crab.tscn",
	"res://battles/tier_2_defender_machopeur.tscn",
	"res://battles/tier_2_machopeur_octopus.tscn",
	"res://battles/tier_2_defender_satyr.tscn",
]
const FIGHTS_ELITE := [
	"res://battles/tier_elite_dragonpriest.tscn",
	"res://battles/tier_elite_lich.tscn",
	"res://battles/tier_elite_gargantua.tscn",
]
const FIGHTS_BOSS := [
	"res://battles/tier_boss_leviathan.tscn",
]

var _bg_material: Material
var _out_dir := ""
var _only := ""
var _geometry := {}


func _ready() -> void:
	_out_dir = OS.get_environment("BG_AUDIT_OUT")
	if _out_dir == "":
		_out_dir = "user://bg_audit"
	_only = OS.get_environment("BG_AUDIT_ONLY")
	DirAccess.make_dir_recursive_absolute(_out_dir)

	# Steal the grading shader material from the real battle scene so renders match
	# in-game; instantiate() without add_child never runs _ready, so this is inert.
	var battle := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	_bg_material = battle.get_node("Background").material
	battle.free()

	for scene_path in FIGHTS_T0:
		await _render(scene_path, "act1_hallway")
	for scene_path in FIGHTS_T12:
		await _render(scene_path, "act1_hallway")
		await _render(scene_path, "act2_hallway")
	for scene_path in FIGHTS_ELITE:
		await _render(scene_path, "act1_elite")
		await _render(scene_path, "act2_elite")
	for scene_path in FIGHTS_BOSS:
		await _render(scene_path, "act1_boss")
		await _render(scene_path, "act2_boss")

	var f := FileAccess.open(_out_dir.path_join("geometry.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_geometry, "  "))
	f.close()
	print("[bg-audit] done -> ", _out_dir)
	get_tree().quit()


func _render(scene_path: String, bg_key: String) -> void:
	var fight_name := scene_path.get_file().get_basename()
	if _only != "" and not fight_name.contains(_only):
		return
	var out_name := "%s__%s" % [fight_name, bg_key]

	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = load(BG_PATHS[bg_key])
	bg.material = _bg_material
	vp.add_child(bg)

	var cam := Camera2D.new()
	cam.position = Vector2(639, 361)
	vp.add_child(cam)
	cam.make_current()

	# Real player at battle.tscn's position: gives the action pickers their "player"
	# group target and shows the shared ground line the enemies must agree with.
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(207, 426)
	vp.add_child(player)
	player.stats = load("res://characters/warrior/warrior.tres")

	var fight: Node = (load(scene_path) as PackedScene).instantiate()
	vp.add_child(fight)

	for i in 6:
		await get_tree().process_frame

	var enemies: Array = []
	for child in fight.get_children():
		if child is Enemy:
			enemies.append(child)
	var inject := OS.get_environment("BG_AUDIT_STATUSES")
	for enemy in enemies:
		enemy.update_action()
		enemy._on_mouse_entered()  # force the hover name label visible/positioned for verification
		if inject != "":
			# BG_AUDIT_STATUSES=weak,exposed - verify the status row's placement/legibility
			for id in inject.split(","):
				var path := "res://statuses/%s.tres" % id.strip_edges()
				if ResourceLoader.exists(path):
					enemy.status_handler.add_status(load(path).duplicate())

	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png(_out_dir.path_join(out_name + ".png"))
	print("[bg-audit] rendered ", out_name)

	var rects := []
	for enemy in enemies:
		var sprite: Sprite2D = enemy.sprite_2d
		var r := sprite.get_rect()
		var tl: Vector2 = sprite.to_global(r.position)
		var br: Vector2 = sprite.to_global(r.end)
		rects.append({
			"name": String(enemy.name),
			"pos": [enemy.position.x, enemy.position.y],
			"scale": enemy.scale.x,
			"texture": sprite.texture.resource_path,
			"sprite_rect": [tl.x, tl.y, br.x, br.y],
			"intent_rect": _ctrl_rect(enemy.intent_ui),
			"stats_rect": _ctrl_rect(enemy.stats_ui),
			"status_rect": _ctrl_rect(enemy.status_handler),
			"name_label_rect": _ctrl_rect(enemy.name_label),
			# NameLabel's own get_global_rect() is unreliable (CanvasLayer-nested, see
			# feedback_enemy_name_label_centering memory) - these are the values that
			# actually matter for verifying label centering by hand.
			"enemy_global_pos": [enemy.global_position.x, enemy.global_position.y],
			"enemy_scale": [enemy.scale.x, enemy.scale.y],
			"name_label_layer_offset": [enemy.name_label_layer.offset.x, enemy.name_label_layer.offset.y],
			"content_center_x": enemy.stats.content_center_x,
		})
	_geometry[out_name] = rects

	vp.queue_free()
	await get_tree().process_frame


func _ctrl_rect(ctrl: Node) -> Array:
	if not ctrl is Control:
		return []
	var r: Rect2 = (ctrl as Control).get_global_rect()
	return [r.position.x, r.position.y, r.end.x, r.end.y]
