extends Node

# Temporary render harness for the dice-aura "emanation" rework (2026-07-23).
# Renders the active-die cluster (dice_interface row + big die) over the act-1 hallway
# battle background at several banked-power charge levels, one PNG per (type, power).
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_dice_glow.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Env:
#   DICE_GLOW_OUT    = absolute output dir (falls back to user://dice_glow)
#   DICE_GLOW_TYPES  = optional comma list of dice types (default: blue,magma,evil)
#   DICE_GLOW_POWERS = optional comma list of banked-power levels (default: 0,6,15)

const VIEW := Vector2i(1280, 720)
const POWER_LEVELS := [0, 6, 15]
# How long to let the charge tweens + shader TIME settle before the shot.
const SETTLE_FRAMES := 45


func _ready() -> void:
	var out_dir := OS.get_environment("DICE_GLOW_OUT")
	if out_dir == "":
		out_dir = "user://dice_glow"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var types: Array = ["blue", "magma", "evil"]
	var types_env := OS.get_environment("DICE_GLOW_TYPES")
	if types_env != "":
		types = types_env.split(",")

	var powers: Array = POWER_LEVELS
	var powers_env := OS.get_environment("DICE_GLOW_POWERS")
	if powers_env != "":
		powers = []
		for token in powers_env.split(","):
			powers.append(int(token))

	# Own a few dice so the interface row shows realistic content.
	Global.blue_dice_max_amount = 2
	Global.blue_dice_current_amount = 2
	Global.red_dice_max_amount = 1
	Global.red_dice_current_amount = 1
	Global.magma_dice_max_amount = 1
	Global.magma_dice_current_amount = 1
	Global.evil_dice_max_amount = 1
	Global.evil_dice_current_amount = 1

	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	# Approximate the in-battle background treatment (real one runs
	# battle_background.gdshader at brightness 0.74).
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(VIEW)
	bg.modulate = Color(0.74, 0.74, 0.74)
	vp.add_child(bg)

	var dice_interface: Control = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	vp.add_child(dice_interface)
	dice_interface.position = Vector2(514, 214)
	dice_interface.size = Vector2(160, 72)

	var dice: Control = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	vp.add_child(dice)
	dice.position = Vector2(521, 294)
	dice.size = Vector2(144, 144)

	for i in 30:
		await get_tree().process_frame

	for type in types:
		dice._on_active_dice_changed(type)
		for power in powers:
			Global.roll_value = power
			dice._set_power_text(power)
			dice._update_dice_aura_charge()
			for i in SETTLE_FRAMES:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.save_png(out_dir.path_join("%s_p%02d.png" % [type, power]))
			print("[dice-glow] saved %s p%d" % [type, power])

	# Optional motion capture: DICE_GLOW_ANIM="type:power" saves a frame sequence
	# (every 2nd frame for ~2s), with a landing surge spiked at the start so the
	# flare-and-decay is visible in the strip. Assemble with ffmpeg afterwards.
	var anim_env := OS.get_environment("DICE_GLOW_ANIM")
	if anim_env != "":
		var parts := anim_env.split(":")
		var anim_type := parts[0]
		var anim_power := int(parts[1]) if parts.size() > 1 else 6
		dice._on_active_dice_changed(anim_type)
		Global.roll_value = anim_power
		dice._set_power_text(anim_power)
		dice._update_dice_aura_charge()
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		if dice.emanation.material is ShaderMaterial:
			dice.emanation.material.set_shader_parameter("surge", 1.0)
			var decay := create_tween()
			decay.tween_property(dice.emanation.material, "shader_parameter/surge", 0.0, 0.55) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var anim_dir := out_dir.path_join("anim_%s_p%02d" % [anim_type, anim_power])
		DirAccess.make_dir_recursive_absolute(anim_dir)
		for f in 60:
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var frame_img := vp.get_texture().get_image()
			frame_img.save_png(anim_dir.path_join("f%03d.png" % f))
		print("[dice-glow] anim saved -> ", anim_dir)

	print("[dice-glow] done -> ", out_dir)
	get_tree().quit()
