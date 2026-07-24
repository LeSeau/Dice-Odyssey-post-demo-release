extends Node

# Calibration harness for coin-vs-number vertical alignment (2026-07-23 shop rework).
# Renders a FAITHFUL 80px top-bar strip (the earlier standalone-GoldUI harness rendered
# at natural ~40px height and lied about alignment) + both shops with Global.gold = 10
# so every price digit renders RED (#FF4444) - trivially separable from the warm-gold
# coin sprite by the measurement script (scratchpad measure_align.py).
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_price_align.tscn
#       --rendering-driver opengl3 --position 2000,2000

const VIEW := Vector2i(1280, 720)


func _ready() -> void:
	var out_dir := OS.get_environment("SHOP_REWORK_OUT")
	if out_dir == "":
		out_dir = "user://shop_rework"
	DirAccess.make_dir_recursive_absolute(out_dir)

	Global.shop_initialized = true
	Global.shop_dice_selection = [5, 6, 7]
	Global.shop_dice_deal_index = 2
	Global.gold = 10

	await _render_topbar(out_dir.path_join("align_topbar.png"))
	await _render_scene("res://scenes/shop/dice_shop.tscn", out_dir.path_join("align_dice.png"), false)
	await _render_scene("res://scenes/shop/card_shop.tscn", out_dir.path_join("align_card.png"), true)
	print("[price-align] done -> ", out_dir)
	get_tree().quit()


# Replicates TopBar/BarItems exactly: 80px-tall HBox, GoldUI instance (min width 82),
# then the heart+HealthLabel HBox with the same separation/size flags as run.tscn.
func _render_topbar(out_png: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(420, 80)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := ColorRect.new()
	bg.size = Vector2(420, 80)
	bg.color = Color(0.09, 0.2, 0.2)
	vp.add_child(bg)

	var strip := HBoxContainer.new()
	strip.position = Vector2.ZERO
	strip.size = Vector2(420, 80)
	strip.add_theme_constant_override("separation", 12)
	vp.add_child(strip)

	var gold_ui: Control = (load("res://scenes/ui/gold_ui.tscn") as PackedScene).instantiate()
	gold_ui.custom_minimum_size = Vector2(82, 0)
	strip.add_child(gold_ui)
	gold_ui.get_node("Label").text = "75"

	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", -3)
	strip.add_child(hp)
	var heart := TextureRect.new()
	heart.custom_minimum_size = Vector2(40, 40)
	heart.texture = load("res://assets/images/heart.png")
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hp.add_child(heart)
	var hpl := Label.new()
	hpl.custom_minimum_size = Vector2(65, 0)
	hpl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hpl.label_settings = load("res://scenes/ui/topbar_label_settings.tres")
	hpl.text = "66/66"
	hpl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp.add_child(hpl)

	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_png)
	vp.queue_free()


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
	vp.get_texture().get_image().save_png(out_png)
	vp.queue_free()
