extends Node

# Checks the three things the raised dice row (top 202) forced: the Scout panel's clearance,
# the dice tooltip's bottom-anchored placement at its restored 204 width, and that the die's
# hop (plus the "+N" popup) now draws IN FRONT of the slot row instead of sliding behind it.


func _ready() -> void:
	Global.tutorial_on = true
	var music := AudioServer.get_bus_index("Music")
	if music >= 0:
		AudioServer.set_bus_mute(music, true)

	var battle: Node = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	battle.battle_stats = load("res://battles/tier_0_machopeur.tres")
	add_child(battle)
	for i in 40:
		await get_tree().process_frame

	Global.dice_type = "blue"
	battle._on_scout_effect(6)
	# Wait in GAME TIME, not frames: since the 2026-08-29 summon pass the panel only unfurls once
	# the comet reaches it, and a frame count means wildly different amounts of time depending on
	# how fast this machine renders. 1.6s clears flight + unfurl with room to spare.
	await get_tree().create_timer(1.6).timeout
	var sp: Control = battle.get_node("ScoutPanel")
	var r: Rect2 = sp.get_global_rect()
	print("[layout] SCOUT frame %d %s topGap=%.0f rowGap=%.0f"
			% [Engine.get_process_frames(), str(r), r.position.y - 80.0, 202.0 - r.end.y])
	sp.hide()

	for spec in [["blue", false], ["magma", true]]:
		if spec[1]:
			Global.dice_infusions[spec[0]] = DiceInfusions.INFUSIONS[spec[0]]["id"]
		var tip: CanvasLayer = (load("res://scenes/ui/dice_tooltip.tscn") as PackedScene).instantiate()
		add_child(tip)
		var panel = tip.get_node("DiceTooltip")
		panel.get_tooltip_content(spec[0])
		panel.show_tooltip_above(196.0, 594.0, 56.0)
		for i in 40:
			await get_tree().process_frame
		var tr: Rect2 = panel.get_global_rect()
		print("[layout] TIP %s%s frame %d %s topGap=%.0f rowGap=%.0f"
				% [spec[0], "+" if spec[1] else "", Engine.get_process_frames(), str(tr),
				tr.position.y - 80.0, 202.0 - tr.end.y])
		tip.queue_free()
		await get_tree().process_frame
	Global.dice_infusions.clear()

	# A real roll, so the hop and the "+N" popup are captured against the row.
	var die: Node = battle.get_node("ActiveDice")
	print("[layout] ROLL start frame %d" % Engine.get_process_frames())
	die.roll_dice()
	for i in 40:
		await get_tree().process_frame
	print("[layout] ROLL done frame %d" % Engine.get_process_frames())
	get_tree().quit()
