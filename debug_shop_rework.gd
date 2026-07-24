extends Node

# Temporary render harness for the 2026-07-23 shop rework:
#   - dice shop "deal of the day" die (4th column, -20% badge, struck-through price)
#   - card shop "Remove a Card" service button (bottom-left)
#   - retuned card/relic prices
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_shop_rework.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Env: SHOP_REWORK_OUT = absolute output dir (falls back to user://shop_rework)

const VIEW := Vector2i(1280, 720)


func _ready() -> void:
	var out_dir := OS.get_environment("SHOP_REWORK_OUT")
	if out_dir == "":
		out_dir = "user://shop_rework"
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Deterministic dice shop: blue/red/green on sale, magma (index 2) as the -20% deal.
	Global.gold = 500
	Global.shop_initialized = true
	Global.shop_dice_selection = [5, 6, 7]
	Global.shop_dice_deal_index = 2

	await _render_scene("res://scenes/shop/dice_shop.tscn", out_dir.path_join("dice_shop_deal.png"), false)
	await _render_scene("res://scenes/shop/card_shop.tscn", out_dir.path_join("card_shop_removal.png"), true)

	# Low-gold pass: removal price should render red with the button disabled.
	Global.gold = 10
	await _render_scene("res://scenes/shop/card_shop.tscn", out_dir.path_join("card_shop_poor.png"), true)

	print("[shop-rework-render] done -> ", out_dir)
	get_tree().quit()


func _render_scene(path: String, out_png: String, is_card_shop: bool) -> void:
	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var scene: Control = (load(path) as PackedScene).instantiate()
	if is_card_shop:
		var warrior := load("res://characters/warrior/warrior.tres") as CharacterStats
		var char_stats := warrior.create_instance() as CharacterStats
		var relic_handler: RelicHandler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
		vp.add_child(relic_handler)
		scene.char_stats = char_stats
		scene.run_stats = RunStats.new()
		scene.relic_handler = relic_handler
		vp.add_child(scene)
		scene.populate_shop()
	else:
		vp.add_child(scene)

	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png(out_png)
	vp.queue_free()
