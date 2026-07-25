extends Node

# Renders every intent TYPE side by side with the live IntentUI (bob included) and checks
# each one's tooltip lookup still resolves, since that keys off the texture FILE BASENAME
# and the block icon moved to a new filename.
#   ... res://debug_intent_family.tscn --write-movie <dir>/f.png --fixed-fps 30
#       --resolution 1280x720 --rendering-driver opengl3 --position 2000,2000

const ICONS := [
	["attack_icon_intent.png", "7"],
	["block_icon_intent.png", "9"],
	["debuff_intent.png", "2"],
	["buff_icon_intent.png", "3"],
	["buff_block_intent.png", "5"],
]


func _ready() -> void:
	Global.tutorial_on = true
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(1280, 720)
	bg.modulate = Color(0.74, 0.74, 0.74)
	add_child(bg)

	var layer := CanvasLayer.new()
	add_child(layer)
	var scene: PackedScene = load("res://scenes/ui/intent_ui.tscn")
	for i in ICONS.size():
		var iu = scene.instantiate()
		layer.add_child(iu)
		iu.position = Vector2(90 + i * 235, 300)
		var it := Intent.new()
		it.icon = load("res://" + ICONS[i][0])
		it.current_text = ICONS[i][1]
		iu.update_intent(it)
		await get_tree().process_frame
		print("[fam] %-24s tooltip=%s" % [ICONS[i][0], iu._get_tooltip_text_for_icon()])

	for f in 40:
		await get_tree().process_frame
	print("[fam] done")
	get_tree().quit()
