extends Node

# A/B idle-animation preview renderer (2026-07-23).
# Variant "current"  = the shipped transform bob (AnimationPlayer "idle", driven
#                      deterministically via seek so the GIF loops perfectly).
# Variant "proposed" = feet-planted sway shader (debug_idle_sway.gdshader): the body
#                      deforms while the feet and ground shadow stay put.
# Saves one PNG per frame; GIFs are assembled afterwards with PIL.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_idle_sway.tscn \
#       --rendering-driver opengl3 --position 2000,2000
# Env:
#   IDLE_SWAY_OUT = absolute output dir (falls back to user://idle_sway)

const VIEW := Vector2i(400, 560)
const FPS := 10
const CENTER_X := 200.0
const FEET_Y := 470.0
const BG_PATH := "res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png"
const SWAY_SHADER_PATH := "res://debug_idle_sway.gdshader"

# screen_params are tuned in SCREEN pixels; they get divided by the sprite's scale
# before being pushed to the shader (which works in texture pixels).
# "loop" must be a multiple of the subject's idle animation length so the "current"
# variant loops without a seam (enemy idle = 4.0s, player idle = 2.6s).
const SUBJECTS := [
	{
		"key": "hero",
		"kind": "player",
		"loop": 5.2,
		"bg_focus": Vector2(250, 540),
		"screen_params": {
			"sway_px": 4.0, "sway_cycles": 1.0, "head_px": 2.0, "head_lag": 0.9,
			"breathe_px": 3.0, "breathe_cycles": 2.0,
		},
	},
	{
		"key": "goblin",
		"kind": "enemy",
		"stats": "res://enemies/goblin/goblin_enemy.tres",
		"loop": 4.0,
		"bg_focus": Vector2(810, 540),
		"screen_params": {
			"sway_px": 4.5, "sway_cycles": 1.0, "head_px": 2.5, "head_lag": 0.8,
			"breathe_px": 3.0, "breathe_cycles": 2.0,
		},
	},
	{
		"key": "marauder",
		"kind": "enemy",
		"stats": "res://enemies/machopeur/machopeur_enemy.tres",
		"loop": 4.0,
		"bg_focus": Vector2(810, 540),
		# Armored bruiser: barely leans, one slow heavy breath per loop is the read.
		"screen_params": {
			"sway_px": 1.8, "sway_cycles": 1.0, "head_px": 1.0, "head_lag": 0.7,
			"breathe_px": 3.5, "breathe_cycles": 1.0,
		},
	},
	{
		"key": "lurker",
		"kind": "enemy",
		"stats": "res://enemies/lurker/lurker_enemy.tres",
		"loop": 4.0,
		"bg_focus": Vector2(810, 540),
		# Grounded organic (Julien 2026-07-23: Lurker has paws, NOT a floater) - hunched
		# posture, so a modest lean + normal breath, feet planted.
		"screen_params": {
			"sway_px": 3.5, "sway_cycles": 1.0, "head_px": 2.0, "head_lag": 0.8,
			"breathe_px": 2.5, "breathe_cycles": 2.0,
		},
	},
	{
		"key": "kraken",
		"kind": "enemy",
		"stats": "res://enemies/octopus/octopus_enemy.tres",
		"loop": 4.0,
		"bg_focus": Vector2(810, 540),
		# Floater (the only one, per Julien): hover drift + sway, almost no breathing.
		"screen_params": {
			"sway_px": 3.5, "sway_cycles": 1.0, "head_px": 2.0, "head_lag": 1.1,
			"breathe_px": 1.0, "breathe_cycles": 2.0, "drift_px": 3.0, "drift_cycles": 1.0,
		},
	},
]

var _out := ""
var _bg_material: Material


func _ready() -> void:
	_out = OS.get_environment("IDLE_SWAY_OUT")
	if _out == "":
		_out = "user://idle_sway"
	DirAccess.make_dir_recursive_absolute(_out)

	# Steal the grading shader from the real battle scene so renders match in-game;
	# instantiate() without add_child never runs _ready, so this is inert.
	var battle := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	_bg_material = battle.get_node("Background").material
	battle.free()

	for subject in SUBJECTS:
		await _render_subject(subject, "current")
		await _render_subject(subject, "proposed")
	print("[idle-sway] done -> ", _out)
	get_tree().quit()


func _render_subject(subject: Dictionary, variant: String) -> void:
	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = load(BG_PATH)
	bg.material = _bg_material
	bg.position = Vector2(CENTER_X, FEET_Y) - (subject["bg_focus"] as Vector2)
	vp.add_child(bg)

	var actor: Node
	if subject["kind"] == "player":
		actor = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
		vp.add_child(actor)
		actor.get_node("StatsUI").visible = false
		actor.get_node("StatusHandler").visible = false
	else:
		actor = (load("res://scenes/enemy/enemy.tscn") as PackedScene).instantiate()
		actor.stats = load(subject["stats"])
		vp.add_child(actor)
		actor.get_node("StatsUI").visible = false
		actor.get_node("IntentUI").visible = false
		actor.get_node("StatusHandler").visible = false
	var sprite: Sprite2D = actor.get_node("SpriteRoot/Sprite2D")
	var anim: AnimationPlayer = actor.get_node("AnimationPlayer")

	for i in 6:
		await get_tree().process_frame

	# Deterministic baseline: kill the (phase-randomized) autoplay idle and zero out
	# SpriteRoot before measuring/centering.
	anim.stop()
	var sprite_root: Node2D = actor.get_node("SpriteRoot")
	sprite_root.position = Vector2.ZERO
	sprite_root.rotation = 0.0
	sprite_root.scale = Vector2.ONE
	await get_tree().process_frame

	# Center the sprite's box on CENTER_X, bottom of the box on FEET_Y.
	var r := sprite.get_rect()
	var tl := sprite.to_global(r.position)
	var br := sprite.to_global(r.end)
	actor.position += Vector2(CENTER_X - (tl.x + br.x) * 0.5, FEET_Y - br.y)

	var loop_seconds: float = subject["loop"]
	var frames := int(round(loop_seconds * FPS))

	var mat: ShaderMaterial
	if variant == "proposed":
		mat = ShaderMaterial.new()
		mat.shader = load(SWAY_SHADER_PATH)
		var s := sprite.scale.x
		mat.set_shader_parameter("tex_size", sprite.texture.get_size())
		mat.set_shader_parameter("loop_seconds", loop_seconds)
		mat.set_shader_parameter("margin_px", 6.0 / s)
		var params: Dictionary = subject["screen_params"]
		for p in params:
			var v: float = params[p]
			if p.ends_with("_px"):
				v = v / s  # tuned in screen px, shader wants texture px
			mat.set_shader_parameter(p, v)
		sprite.material = mat
	else:
		anim.play("idle")
		anim.speed_scale = 0.0

	for f in frames:
		var t := float(f) / float(FPS)
		if variant == "proposed":
			mat.set_shader_parameter("anim_time", t)
		else:
			anim.seek(fmod(t, anim.current_animation_length), true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(_out.path_join("%s_%s_%03d.png" % [subject["key"], variant, f]))

	print("[idle-sway] rendered %s %s (%d frames)" % [subject["key"], variant, frames])
	vp.queue_free()
	await get_tree().process_frame
