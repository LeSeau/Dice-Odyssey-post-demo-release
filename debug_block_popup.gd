extends Node

# Harness for the post-block damage display (2026-08-04, itch feedback: "attacked for 6
# with 5 block should only show 1"). Boots a REAL battle.tscn through start_battle()
# (same recipe as debug_double_endturn.gd), then fires DamageEffects at the player and an
# enemy with various block amounts and asserts:
#   - Global.damage_to_display / blocked_to_display carry the post-block split
#   - the spawned popup label reads the NET number ("-1"), or "Blocked" when fully soaked
#   - a 0-damage hit with no block still reads "-0" (must NOT say "Blocked")
#   - HP actually moves by exactly the displayed number
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_block_popup.tscn \
#       --rendering-driver opengl3 --position 2000,2000

const FIGHT := "res://battles/tier_1_crab_satyr.tres"
const POPUP_SCENE_PATH := "res://scenes/ui/damage_popup.tscn"
# Optional render of the "Blocked" popup mid-animation (set via OS env BLOCK_POPUP_RENDER).
var render_path := OS.get_environment("BLOCK_POPUP_RENDER")

var hands_drawn := 0
var fails := 0
var _vp: SubViewport


func _ready() -> void:
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	var battle := await _boot_battle()

	var player: Player = Global.player
	var enemy := _first_enemy(battle)
	_check("boot: player found", player != null, str(player))
	_check("boot: enemy found", enemy != null, str(enemy))
	if player == null or enemy == null:
		get_tree().quit(1)
		return

	# 1) Partial block on the player: 6 into 5 block -> "-1", HP -1, block spent.
	var hp0: int = player.stats.health
	player.stats.block = 5
	_hit(player, 6)
	_check("P1 display == 1", Global.damage_to_display == 1,
			"damage_to_display=%d" % Global.damage_to_display)
	_check("P1 blocked == 5", Global.blocked_to_display == 5,
			"blocked_to_display=%d" % Global.blocked_to_display)
	_check("P1 popup '-1'", _last_popup_text(player) == "-1",
			"popup='%s'" % _last_popup_text(player))
	_check("P1 hp -1", player.stats.health == hp0 - 1,
			"hp %d -> %d" % [hp0, player.stats.health])
	_check("P1 block spent", player.stats.block == 0, "block=%d" % player.stats.block)
	await _settle(player)

	# 2) Full block on the player: 6 into 10 -> "Blocked", HP unchanged, block 4 left.
	hp0 = player.stats.health
	player.stats.block = 10
	_hit(player, 6)
	if render_path != "":
		# Let the spawn flash settle to the popup's true steel-blue before capturing.
		await get_tree().create_timer(0.15).timeout
		_vp.get_texture().get_image().save_png(render_path)
		print("[block-popup] render saved: ", render_path,
				" player_pos=", player.global_position)
	_check("P2 display == 0", Global.damage_to_display == 0,
			"damage_to_display=%d" % Global.damage_to_display)
	_check("P2 popup 'Blocked'", _last_popup_text(player) == "Blocked",
			"popup='%s'" % _last_popup_text(player))
	_check("P2 hp unchanged", player.stats.health == hp0,
			"hp %d -> %d" % [hp0, player.stats.health])
	_check("P2 block 4 left", player.stats.block == 4, "block=%d" % player.stats.block)
	await _settle(player)

	# 3) No block on the player: 6 -> "-6" (unchanged pre-existing behavior).
	hp0 = player.stats.health
	player.stats.block = 0
	_hit(player, 6)
	_check("P3 popup '-6'", _last_popup_text(player) == "-6",
			"popup='%s'" % _last_popup_text(player))
	_check("P3 hp -6", player.stats.health == hp0 - 6,
			"hp %d -> %d" % [hp0, player.stats.health])
	await _settle(player)

	# 4) Zero-damage hit with no block: "-0", NOT "Blocked".
	_hit(player, 0)
	_check("P4 popup '-0'", _last_popup_text(player) == "-0",
			"popup='%s'" % _last_popup_text(player))
	await _settle(player)

	# 5) Partial block on an ENEMY: 12 into 5 block -> "-7", HP -7.
	var ehp0: int = enemy.stats.health
	enemy.stats.block = 5
	_hit(enemy, 12)
	_check("E1 display == 7", Global.damage_to_display == 7,
			"damage_to_display=%d" % Global.damage_to_display)
	_check("E1 popup '-7'", _last_popup_text(enemy) == "-7",
			"popup='%s'" % _last_popup_text(enemy))
	_check("E1 hp -7", enemy.stats.health == ehp0 - 7,
			"hp %d -> %d" % [ehp0, enemy.stats.health])
	await _settle(enemy)

	# 6) Full block on an ENEMY: 6 into 20 -> "Blocked", HP unchanged.
	ehp0 = enemy.stats.health
	enemy.stats.block = 20
	_hit(enemy, 6)
	_check("E2 popup 'Blocked'", _last_popup_text(enemy) == "Blocked",
			"popup='%s'" % _last_popup_text(enemy))
	_check("E2 hp unchanged", enemy.stats.health == ehp0,
			"hp %d -> %d" % [ehp0, enemy.stats.health])
	await _settle(enemy)

	if fails == 0:
		print("[block-popup] ALL PASS")
	else:
		print("[block-popup] %d FAIL(S)" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("[block-popup] PASS  ", name, "  (", detail, ")")
	else:
		fails += 1
		print("[block-popup] FAIL  ", name, "  (", detail, ")")


func _hit(target: Node, amount: int) -> void:
	var eff := DamageEffect.new()
	eff.amount = amount
	eff.sound = load("res://sounds/error.wav")
	var targets: Array[Node] = [target]
	eff.execute(targets)


func _last_popup_text(target: Node) -> String:
	var found: Node = null
	for child in target.get_parent().get_children():
		if child.scene_file_path == POPUP_SCENE_PATH and not child.is_queued_for_deletion():
			found = child
	if found == null:
		return "<none>"
	return (found.get_node("Label") as Label).text


func _settle(target: Node) -> void:
	for child in target.get_parent().get_children():
		if child.scene_file_path == POPUP_SCENE_PATH:
			child.queue_free()
	for i in 3:
		await get_tree().process_frame


func _await_until(cond: Callable, timeout_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _boot_battle() -> Battle:
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var battle: Battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	_vp.add_child(battle)

	var relic_handler: RelicHandler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	# HBoxContainer needs a Control ancestor or its layout collapses to zero (documented
	# harness trap).
	var host := Control.new()
	host.size = Vector2(400, 80)
	_vp.add_child(host)
	host.add_child(relic_handler)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	battle.char_stats = warrior.create_instance()
	battle.relics = relic_handler
	battle.battle_stats = load(FIGHT)
	battle.act_tier = 1

	var drawn_before := hands_drawn
	battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > drawn_before, 15.0)
	for i in 20:
		await get_tree().process_frame
	return battle


func _first_enemy(battle: Node) -> Enemy:
	var handler := battle.find_child("EnemyHandler", true, false)
	if handler == null:
		return null
	for child in handler.get_children():
		if child is Enemy and not child.is_queued_for_deletion():
			return child
	return null
