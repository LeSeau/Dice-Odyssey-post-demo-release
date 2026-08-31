extends Node

# Renders the new relics through the REAL RelicHandler (relic_ui.tscn at its real 46px top-bar
# size, KEEP_ASPECT_COVERED and all) on the game's top-bar navy, so the icons are judged where
# they actually live rather than as loose PNGs. Catches import/compression damage and any
# icon whose silhouette collapses at 46px.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_relic_row_render.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const NEW_RELICS := [
	"underdog_ring", "needle_die", "worms_eye_lens", "sixth_gear", "conductors_baton",
	"giants_signet", "pilot_light", "marked_deck", "consolation_chip", "jackpot_pin",
	"blood_chalice", "whetstone_pendant", "mortar_trowel", "thorned_plate", "fuel_gauge",
	"wayfinder_compass", "diplomats_seal", "stray_die", "alms_box", "hagglers_loupe",
	"golem_heart",
]
# A few shipped relics rendered alongside, so the new icons can be compared against the
# existing ones for visual weight rather than judged in isolation.
const EXISTING := ["crown", "hunting_bow", "metronome", "prayer_beads", "coupons",
		"gamblers_fan", "spyglass", "snake_eyes_charm", "runic_bones", "magic_sleeve"]

const OUT := "res://relic_row_render.png"


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 220)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var bg := ColorRect.new()
	bg.color = Color(0.094, 0.114, 0.180)  # the top bar's navy
	bg.size = Vector2(1280, 220)
	viewport.add_child(bg)

	_add_row(viewport, NEW_RELICS, 16.0, "NEW")
	_add_row(viewport, EXISTING, 120.0, "SHIPPED")

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var image := viewport.get_texture().get_image()
	image.save_png(OUT)
	print("saved ", OUT, " ", image.get_size())
	get_tree().quit()


func _add_row(viewport: SubViewport, ids: Array, y: float, label_text: String) -> void:
	var host := Control.new()
	host.position = Vector2(16, y)
	host.size = Vector2(1240, 90)
	viewport.add_child(host)

	var label := Label.new()
	label.text = label_text
	label.position = Vector2(0, -2)
	host.add_child(label)

	var handler: RelicHandler = (
			load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	handler.position = Vector2(0, 18)
	handler.size = Vector2(1240, 60)
	host.add_child(handler)

	for rid: String in ids:
		var relic := load("res://relics/%s.tres" % rid) as Relic
		if relic != null:
			handler.add_relic(relic)
