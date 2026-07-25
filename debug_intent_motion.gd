extends Node

# Render harness for the attack-intent icon swap + the new IntentUI motion (2026-07-25).
# Shows real enemies with real intents on a real background, then forces an intent CHANGE
# partway through so the punch beat is captured alongside the idle breathing pulse.
# Movie Maker mode required (fixed 1/30s deltas):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_intent_motion.tscn
#       --write-movie <out>/f.png --fixed-fps 30 --resolution 1280x720
#       --rendering-driver opengl3 --position 2000,2000
# Env INTENT_BG = "act1" (default) | "act2"   INTENT_FIGHT = res:// battle scene

const BGS := {
	"act1": "res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png",
	"act2": "res://assets/backgrounds/combat_bg_act2_hallway_arcane_library.png",
}


func _ready() -> void:
	if not OS.has_feature("movie"):
		push_error("[intent] run with --write-movie <dir>/f.png --fixed-fps 30 --resolution 1280x720")
		get_tree().quit(1)
		return
	Global.tutorial_on = true

	var which := OS.get_environment("INTENT_BG")
	if which == "" or not BGS.has(which):
		which = "act1"
	var bg := TextureRect.new()
	bg.texture = load(BGS[which])
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(1280, 720)
	bg.modulate = Color(0.74, 0.74, 0.74)
	add_child(bg)

	var cam := Camera2D.new()
	cam.position = Vector2(639, 361)
	add_child(cam)
	cam.make_current()

	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(207, 426)
	add_child(player)
	player.stats = load("res://characters/warrior/warrior.tres")

	var fight_path := OS.get_environment("INTENT_FIGHT")
	if fight_path == "":
		fight_path = "res://battles/tier_1_machopeur_satyr.tscn"
	var fight: Node = (load(fight_path) as PackedScene).instantiate()
	add_child(fight)

	for i in 14:
		await get_tree().process_frame

	# Force a persistent ATTACK intent by hand instead of calling update_action() - the AI
	# re-rolls to a buff/debuff and the sword vanishes mid-capture.
	var enemies: Array[Node] = []
	for child in fight.get_children():
		if child is Enemy:
			enemies.append(child)
	var attack := Intent.new()
	attack.icon = load("res://attack_icon_intent.png")
	attack.current_text = "7"
	for e in enemies:
		e.get("intent_ui").update_intent(attack)
	print("[intent] %d enemies on '%s'" % [enemies.size(), which])

	var iu0 = enemies[0].get("intent_ui")
	var probe: Control = iu0.get_node("IconSlot/Icon")
	var probe_label: Control = iu0.get_node("LabelSlot/Label")
	print("[intent] icon size=%s  label slot=%s" % [str(probe.size), str(iu0.get_node("LabelSlot").size)])

	# One full bob cycle or two, traced. Should be a smooth sine between -3 and +3 with no
	# discontinuities - a jump mid-run means the container re-sorted and stomped the position.
	print("[intent] --- bob cycles ---")
	await _trace(probe, probe_label, 62)
	# Changing the damage number changes the Label's width, which makes the HBoxContainer
	# re-sort. That is the exact case the IconSlot wrapper exists to survive: the bob must
	# keep going smoothly across it.
	print("[intent] --- number changes (forces a container re-sort) ---")
	var bumped := Intent.new()
	bumped.icon = attack.icon
	bumped.current_text = "13"
	for e in enemies:
		e.get("intent_ui").update_intent(bumped)
	await _trace(probe, probe_label, 40)
	print("[intent] done")
	get_tree().quit()


func _trace(probe: Control, probe_label: Control, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
		var d: float = probe.position.y - probe_label.position.y
		print("[intent]   icon %+.2f  label %+.2f  delta %+.2f%s" % [
				probe.position.y, probe_label.position.y, d, "  <-- DESYNC" if absf(d) > 0.01 else ""])
