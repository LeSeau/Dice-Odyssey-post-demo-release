extends Node

# Temporary render harness to verify the Pixie Dice rename shows correctly on the dice
# infusion screen (2026-07-16). Forces green (Pixie) dice to be owned so it's guaranteed
# to appear as a candidate alongside Blue.
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_dice_infusion_render.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Env:
#   DICE_INFUSION_OUT = absolute output dir (falls back to user://dice_infusion_render)

const VIEW := Vector2i(1280, 720)


func _ready() -> void:
	var out_dir := OS.get_environment("DICE_INFUSION_OUT")
	if out_dir == "":
		out_dir = "user://dice_infusion_render"
	DirAccess.make_dir_recursive_absolute(out_dir)

	Global.green_dice_max_amount = 1
	Global.blue_dice_max_amount = 2
	Global.red_dice_max_amount = 0
	Global.dice_infusions = {}

	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var screen: Control = (load("res://scenes/dice_infusion/dice_infusion.tscn") as PackedScene).instantiate()
	vp.add_child(screen)

	# The entrance tween (title fade/scale + staggered panel fades + die pops) takes
	# ~1.5-2s - wait it out fully rather than screenshotting mid-fade.
	for i in 200:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("dice_infusion.png"))
	print("[dice-infusion-render] done -> ", out_dir)
	get_tree().quit()
