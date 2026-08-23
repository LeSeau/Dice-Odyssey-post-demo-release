extends Node

# Renders the relic inspect popup for a few relics (short name, long name, long description,
# Power-glyph description) at the real 1280x720 design canvas, over a stand-in board so the
# dimmer can be judged. Also exercises the close paths.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_relic_inspect.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const SHOTS := ["golem_heart", "cartographers_quill", "prismatic_lens", "overflow_valve"]
const INSPECT := preload("res://scenes/ui/relic_inspect.gd")


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	for rid in SHOTS:
		await _shoot(rid)
	await _click_path_test()
	print("done")
	get_tree().quit()


func _shoot(rid: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	# Stand-in board so the dimmer has something to dim.
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1280, 720)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vp.add_child(bg)

	var relic := load("res://relics/%s.tres" % rid) as Relic
	var popup = INSPECT.new()
	popup._relic = relic
	vp.add_child(popup)

	for _i in 30:
		await get_tree().process_frame

	var img := vp.get_texture().get_image()
	img.save_png("res://relic_inspect_%s.png" % rid)
	print("shot ", rid, "  panel=", popup._panel.size, " pos=", popup._panel.position)
	vp.queue_free()
	await get_tree().process_frame


# The render above builds the popup directly. This exercises the path that actually matters:
# a click landing on a RelicUI inside a real RelicHandler.
func _click_path_test() -> void:
	var handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(600, 90)
	add_child(host)
	host.add_child(handler)
	await get_tree().process_frame

	handler.add_relic(load("res://relics/golem_heart.tres") as Relic)
	await get_tree().process_frame
	var relic_ui: RelicUI = handler.relics.get_child(0)

	var before := _popup_count()
	# mouse_filter must let the RelicUI itself receive the click, not its Icon child.
	print("CHECK relic_ui filter STOP        : ", relic_ui.mouse_filter == Control.MOUSE_FILTER_STOP)
	print("CHECK icon filter IGNORE          : ",
			relic_ui.get_node("Icon").mouse_filter == Control.MOUSE_FILTER_IGNORE)

	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	relic_ui.gui_input.emit(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var after := _popup_count()
	print("CHECK click opens popup           : ", after == before + 1, "  (", before, "->", after, ")")

	# ...and that it closes again, rather than stacking one popup per click.
	var popup := _find_popup()
	if popup:
		popup.close()
		for _i in 20:
			await get_tree().process_frame
		print("CHECK close frees the popup       : ", _popup_count() == before)
	host.queue_free()


func _popup_count() -> int:
	var n := 0
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.get_script() == INSPECT:
			n += 1
	return n


func _find_popup() -> Node:
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.get_script() == INSPECT:
			return c
	return null
