extends Node

# Temporary render harness (2026-07-19): verifies the act-2 enemy reskin
# (battle.gd ACT2_RESKIN + _reskin_enemy) renders in-engine and grounds acceptably.
# Applies the SAME art/name swap the real code does to each fight's enemies, then
# screenshots them on the act-2 background. Visual-only (HP/damage untouched).
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_act2_reskin.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const VIEW := Vector2i(1280, 720)
const OUT := "C:/Users/julie/AppData/Local/Temp/claude/C--Users-julie-Desktop-daiso-august-copy/84e67efa-8f47-49dc-a8ed-f8b15e4565bf/scratchpad/act2_render"

const BG := {
	"hallway": "res://assets/backgrounds/combat_bg_act2_hallway_arcane_library.png",
	"elite": "res://assets/backgrounds/combat_bg_act2_elite_cool_lava.png",
	"boss": "res://assets/backgrounds/combat_bg_act2_boss_coastal_mist.png",
}

# EVERY act-2-reachable fight (battle_tier 1/2 -> hallway, elites, boss), for the
# full positioning review after the reskin.
const FIGHTS := [
	["res://battles/tier_1_crab_satyr.tscn", "hallway"],
	["res://battles/tier_1_defender.tscn", "hallway"],
	["res://battles/tier_1_lurker.tscn", "hallway"],
	["res://battles/tier_1_machopeur_octopus.tscn", "hallway"],
	["res://battles/tier_1_machopeur_satyr.tscn", "hallway"],
	["res://battles/tier_1_oculus_goblin.tscn", "hallway"],
	["res://battles/tier_1_plant_goblin.tscn", "hallway"],
	["res://battles/tier_1_plant_octopus.tscn", "hallway"],
	["res://battles/tier_1_sigil_slug.tscn", "hallway"],
	["res://battles/tier_1_octopus_2_satyrs_2.tscn", "hallway"],
	["res://battles/tier_1_lurker_crab.tscn", "hallway"],
	["res://battles/tier_2_defender_machopeur.tscn", "hallway"],
	["res://battles/tier_2_defender_satyr.tscn", "hallway"],
	["res://battles/tier_2_hound.tscn", "hallway"],
	["res://battles/tier_2_machopeur_octopus.tscn", "hallway"],
	["res://battles/tier_2_medusa.tscn", "hallway"],
	["res://battles/tier_2_plant_crab.tscn", "hallway"],
	["res://battles/tier_2_vortex.tscn", "hallway"],
	["res://battles/tier_elite_lich.tscn", "elite"],
	["res://battles/tier_elite_dragonpriest.tscn", "elite"],
	["res://battles/tier_elite_gargantua.tscn", "elite"],
	["res://battles/tier_boss_leviathan.tscn", "boss"],
]

var _bg_material: Material


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var battle := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	_bg_material = battle.get_node("Background").material
	battle.free()

	var only := OS.get_environment("RESKIN_ONLY")
	for row in FIGHTS:
		if only != "" and not String(row[0]).contains(only):
			continue
		await _render(row[0], row[1])

	print("[act2-reskin] done -> ", OUT)
	get_tree().quit()


func _render(scene_path: String, bg_key: String, do_reskin: bool = true, name_override: String = "") -> void:
	var fight_name := name_override if name_override != "" else scene_path.get_file().get_basename()

	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = load(BG[bg_key])
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

	var fight: Node = (load(scene_path) as PackedScene).instantiate()
	vp.add_child(fight)

	for i in 6:
		await get_tree().process_frame

	if do_reskin:
		for child in fight.get_children():
			if child is Enemy:
				_reskin(child)

	for child in fight.get_children():
		if child is Enemy:
			child.update_action()
			child._on_mouse_entered()
			var bar_center_local: float = child.stats_ui.position.x + child.stats_ui.size.x / 2.0
			print("[geo] %s name_local_x=%.1f bar_center_local=%.1f delta=%.1f sprite_x=%.1f ccx=%.2f tex=%s scale=%.2f" % [
				child._display_name, child._name_label_local_x, bar_center_local,
				child._name_label_local_x - bar_center_local, child.sprite_2d.position.x,
				child.stats.content_center_x, str(child.sprite_2d.texture.get_size()), child.sprite_2d.scale.x])

	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png(OUT.path_join(fight_name + ".png"))
	print("[act2-reskin] rendered ", fight_name)

	vp.queue_free()
	await get_tree().process_frame


# The real battle.gd::_reskin_enemy (static since 2026-07-31) — no mirror copy to drift.
func _reskin(enemy: Enemy) -> void:
	Battle._reskin_enemy(enemy)
