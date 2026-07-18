extends Node

# Verifies the new IconTooltip visual (2026-07-16): panel style, sizing, font, text.
# Renders into an explicit off-screen SubViewport (the project's established headless-
# render convention - the real, off-screen game WINDOW doesn't reliably read back via
# get_texture(), only a manually created SubViewport with UPDATE_ALWAYS does).
#
# Deliberately bypasses IconTooltip.spawn_below()'s get_tree().root parenting here (that
# part of the design - escaping to root so the tooltip renders above every other
# CanvasLayer - already matches the proven pattern used by every other tooltip in the
# project: tooltip.gd, dice_tooltip.gd, status_tooltip.gd, relic_ui.gd). This harness only
# needs to confirm the NEW visual (panel style/sizing/text) renders correctly, so it adds
# the tooltip's CanvasLayer under the SubViewport directly instead.
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_icon_tooltip_render.tscn
#       --rendering-driver opengl3 --position 2000,2000

const VIEW := Vector2i(1280, 200)
const LABELS := ["Map", "Dice Shop", "Deck", "Settings"]


func _ready() -> void:
	var out_dir := OS.get_environment("ICON_TOOLTIP_OUT")
	if out_dir == "":
		out_dir = "user://icon_tooltip_render"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.16, 0.15)
	bg.size = Vector2(VIEW)
	vp.add_child(bg)

	var x := 60.0
	for label_text in LABELS:
		var layer: Node = load("res://scenes/ui/icon_tooltip.tscn").instantiate()
		vp.add_child(layer)
		var panel: IconTooltip = layer.get_node("IconTooltip")
		panel.show_tooltip(Vector2(x, 40), label_text)
		x += 300.0

	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("icon_tooltip.png"))
	print("[icon-tooltip-render] done -> ", out_dir)
	get_tree().quit()
