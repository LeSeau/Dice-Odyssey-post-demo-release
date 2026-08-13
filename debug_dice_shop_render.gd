extends Node

# Temporary render harness to verify the dice-shop title/texture spacing fix (2026-07-16).
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_dice_shop_render.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Env:
#   DICE_SHOP_OUT = absolute output dir (falls back to user://dice_shop_render)

const VIEW := Vector2i(1280, 720)


func _ready() -> void:
	var out_dir := OS.get_environment("DICE_SHOP_OUT")
	if out_dir == "":
		out_dir = "user://dice_shop_render"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var shop: Control = (load("res://scenes/shop/dice_shop.tscn") as PackedScene).instantiate()
	vp.add_child(shop)

	# ~1.5s of real frames so breathing/motes are underway when the still is captured.
	# Along the way, sample the visible halos' alphas: a still can't show desync, but
	# three well-separated alpha values at one instant (and re-ordered at the next) can.
	for sample in 3:
		for i in 30:
			await get_tree().process_frame
		var line := "[dice-shop-render] glow alphas:"
		for index in Global.shop_dice_selection:
			var tex: TextureRect = shop.get_node(
					"MarginContainer/Panel/HBoxContainer/Dice%d/Dice%dTexture" % [index + 1, index + 1])
			line += " %.3f" % tex.get_child(0).modulate.a
		print(line)
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("dice_shop.png"))
	print("[dice-shop-render] done -> ", out_dir)
	get_tree().quit()
