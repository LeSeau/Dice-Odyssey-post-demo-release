extends Node

# Checks for the 2026-09-24 hit-effect pass (enemy.gd "HIT FX" section, damage_effect.gd HitFx).
# Julien's rule: an attack card's blow draws the die impact; every other source of damage draws
# sparks only, and nothing when a shield eats the whole hit; every hit flinches the body.
#
# Headless is enough (node checks, no pixels):
#   Godot_v4.3-stable_win64_console.exe --headless --path . res://debug_hit_fx.tscn
#
# Spawns are counted as they ENTER the tree (child_entered_tree), not as live nodes: an impact
# frees itself after ~0.25-0.45s, so a live count taken after Flurry's second hit would miss
# the first one.

const FIGHT := "res://battles/tier_1_crab_satyr.tscn"
const FLURRY := "res://characters/warrior/cards/card_flurry.tres"
const HIT_SOUND := preload("res://art/slash.ogg")
const FX_GROUPS := ["hit_fx_impact", "hit_fx_sparks", "hit_fx_chips", "hit_fx_slash"]

var _passes := 0
var _fails := 0
var _enemies: Array[Enemy] = []
# instance id -> {group: spawn count}
var _spawned := {}


func _ready() -> void:
	Global.tutorial_on = true  # keeps achievement toasts out of the way
	Global.dice_type = "blue"
	Global.berserker_boost_active = false

	var cam := Camera2D.new()
	cam.set_script(load("res://scenes/battle/camera_2d.gd"))
	cam.add_to_group("camera")
	add_child(cam)
	# The held-die strike flies its clone on the "ui_layer"; without one it refuses to start.
	var ui := CanvasLayer.new()
	ui.add_to_group("ui_layer")
	add_child(ui)
	var player: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(207, 426)
	add_child(player)
	player.stats = load("res://characters/warrior/warrior.tres")
	var fight: Node = (load(FIGHT) as PackedScene).instantiate()
	add_child(fight)
	for i in 12:
		await get_tree().process_frame

	for c in fight.get_children():
		if c is Enemy:
			var e: Enemy = c
			e.stats.max_health = 999
			e.stats.health = 999
			e.stats.block = 0
			_enemies.append(e)
			var eid := e.get_instance_id()
			_spawned[eid] = {}
			for g in FX_GROUPS:
				_spawned[eid][g] = 0
			e.child_entered_tree.connect(_on_enemy_child_entered.bind(eid))
	if _enemies.size() < 3:
		print("FAIL setup: expected 3 enemies in %s, got %d" % [FIGHT, _enemies.size()])
		get_tree().quit(1)
		return
	print("[hitfx] setup ok, %d enemies, player die strike ready=%s"
			% [_enemies.size(), str(Global.player != null)])

	_check("S0 DIE_IMPACT is the default style",
			Enemy.slash_style == Enemy.SlashStyle.DIE_IMPACT, str(Enemy.slash_style))

	await _section_card_vs_other()
	await _section_blocked()
	await _section_thrown_die()
	await _section_flurry()
	await _section_strike()
	await _section_aoe()
	await _section_flinch()
	await _section_kill()
	await _section_cleanup()

	print("[hitfx] DONE %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _on_enemy_child_entered(node: Node, eid: int) -> void:
	for g in FX_GROUPS:
		if node.is_in_group(g):
			_spawned[eid][g] += 1


func _spawns(e: Enemy, group: String) -> int:
	return int(_spawned[e.get_instance_id()][group])


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		_passes += 1
		print("PASS %s %s" % [label, detail])
	else:
		_fails += 1
		print("FAIL %s %s" % [label, detail])


# card = pretend an attack card is being played this frame (the stamp Card.play() writes).
# Untyped `targets` on purpose: an array literal handed to an Array[Node] parameter is a
# runtime type error, and every call site here passes a literal.
func _hit(targets: Array, amount: int, card: bool,
		fx: DamageEffect.HitFx = DamageEffect.HitFx.AUTO) -> void:
	var typed: Array[Node] = []
	for t in targets:
		typed.append(t)
	if card:
		Global.last_attack_card_played_frame = Engine.get_process_frames()
		Global.last_attack_card_single_target = typed.size() == 1
	var eff := DamageEffect.new()
	eff.amount = amount
	eff.sound = HIT_SOUND
	eff.hit_fx = fx
	eff.execute(typed)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _section_card_vs_other() -> void:
	var e := _enemies[0]
	var imp := _spawns(e, "hit_fx_impact")
	var sp := _spawns(e, "hit_fx_sparks")
	_hit([e], 12, true)
	_check("A1 an attack card's blow draws the die impact",
			_spawns(e, "hit_fx_impact") == imp + 1, "impacts %d" % (_spawns(e, "hit_fx_impact") - imp))
	_check("A2 ...and its sparks", _spawns(e, "hit_fx_sparks") == sp + 1)
	await get_tree().process_frame  # the card stamp is stale from here on

	imp = _spawns(e, "hit_fx_impact")
	sp = _spawns(e, "hit_fx_sparks")
	_hit([e], 12, false)
	_check("B1 non-card damage draws NO die impact", _spawns(e, "hit_fx_impact") == imp,
			"impacts %d" % (_spawns(e, "hit_fx_impact") - imp))
	_check("B2 non-card damage still fires sparks", _spawns(e, "hit_fx_sparks") == sp + 1)

	imp = _spawns(e, "hit_fx_impact")
	_hit([e], 12, false, DamageEffect.HitFx.CARD)
	_check("B3 an explicit CARD blow on a later frame draws the impact",
			_spawns(e, "hit_fx_impact") == imp + 1)
	await _wait(0.6)


func _section_blocked() -> void:
	var e := _enemies[0]
	e.stats.block = 50
	var sp := _spawns(e, "hit_fx_sparks")
	var imp := _spawns(e, "hit_fx_impact")
	_hit([e], 5, false)
	_check("C1 non-card hit fully blocked: no sparks", _spawns(e, "hit_fx_sparks") == sp)
	_check("C2 ...and no impact", _spawns(e, "hit_fx_impact") == imp)
	await get_tree().process_frame
	e.stats.block = 50
	imp = _spawns(e, "hit_fx_impact")
	_hit([e], 5, true)
	_check("C3 a card blow into a full block still draws the impact (it hit the shield)",
			_spawns(e, "hit_fx_impact") == imp + 1)
	e.stats.block = 0
	await _wait(0.6)


func _section_thrown_die() -> void:
	var e := _enemies[0]
	var imp := _spawns(e, "hit_fx_impact")
	var sp := _spawns(e, "hit_fx_sparks")
	var card := Card.new()
	card._on_thrown_die_landed(get_tree(), e, 6, HIT_SOUND, "blue", 6)
	_check("E1 a thrown die's hit draws no die impact (it has its own bash)",
			_spawns(e, "hit_fx_impact") == imp)
	_check("E2 ...only sparks", _spawns(e, "hit_fx_sparks") == sp + 1)
	await _wait(0.6)


func _section_flurry() -> void:
	var e := _enemies[0]
	var flurry: Card = load(FLURRY)
	var handler := ModifierHandler.new()
	Global.roll_value = 5
	var imp := _spawns(e, "hit_fx_impact")
	var flurry_targets: Array[Node] = [e]
	flurry.apply_effects(flurry_targets, handler)
	_check("F1 Flurry's first hit draws the impact", _spawns(e, "hit_fx_impact") == imp + 1)
	await _wait(0.45)
	_check("F2 Flurry's delayed second hit draws the impact too (the play frame is long gone)",
			_spawns(e, "hit_fx_impact") == imp + 2,
			"impacts %d" % (_spawns(e, "hit_fx_impact") - imp))
	handler.free()
	Global.roll_value = 0
	await _wait(0.5)


func _section_strike() -> void:
	var e := _enemies[0]
	var imp := _spawns(e, "hit_fx_impact")
	var hp := e.stats.health
	_hit([e], 22, true)  # STRONG single-target blow: the held die flies it in
	_check("G1 strike: nothing lands while the die is in the air",
			_spawns(e, "hit_fx_impact") == imp and e.stats.health == hp,
			"impacts %d hp %d->%d" % [_spawns(e, "hit_fx_impact") - imp, hp, e.stats.health])
	await _wait(0.5)
	_check("G2 strike: the die impact lands with the die", _spawns(e, "hit_fx_impact") == imp + 1,
			"impacts %d hp %d->%d" % [_spawns(e, "hit_fx_impact") - imp, hp, e.stats.health])
	await _wait(1.0)


func _section_aoe() -> void:
	var before: Array[int] = []
	var targets: Array = []
	for e in _enemies:
		before.append(_spawns(e, "hit_fx_impact"))
		targets.append(e)
	_hit(targets, 12, true)
	var ok := true
	for i in _enemies.size():
		if _spawns(_enemies[i], "hit_fx_impact") != before[i] + 1:
			ok = false
	_check("H1 an AoE card blow draws one impact per enemy", ok)
	await _wait(0.6)


func _section_flinch() -> void:
	var e := _enemies[1]
	await _wait(0.6)
	var lean_peak := 0.0
	var pivot_drift := 0.0
	var feet: Vector2 = e.get("_feet_pivot")
	var root := e.sprite_2d.get_parent() as Node2D
	_hit([e], 12, false)
	var t := 0.0
	while t < 0.3:
		await get_tree().process_frame
		t += get_process_delta_time()
		lean_peak = maxf(lean_peak, e.pose_lean)
		pivot_drift = maxf(pivot_drift, (root.transform * feet - feet).length())
	_check("I1 a MEDIUM hit leans the body away (0.03-0.06 rad)",
			lean_peak >= 0.03 and lean_peak <= 0.06, "peak %.3f" % lean_peak)
	_check("I2 the feet pivot stays planted during the flinch", pivot_drift < 0.05,
			"drift %.3fpx" % pivot_drift)
	await _wait(0.5)
	_check("I3 the lean settles back to zero", absf(e.pose_lean) < 0.002, "lean %.4f" % e.pose_lean)

	var small_peak := 0.0
	_hit([e], 2, false)
	t = 0.0
	while t < 0.3:
		await get_tree().process_frame
		t += get_process_delta_time()
		small_peak = maxf(small_peak, e.pose_lean)
	_check("I4 a tap leans less than a real hit", small_peak > 0.0 and small_peak < lean_peak,
			"tap %.3f vs hit %.3f" % [small_peak, lean_peak])
	await _wait(0.5)

	e.attack_motion_active = true
	var during := 0.0
	_hit([e], 12, false)
	t = 0.0
	while t < 0.25:
		await get_tree().process_frame
		t += get_process_delta_time()
		during = maxf(during, absf(e.pose_lean))
	_check("J1 no flinch while the enemy's own attack owns the pose", during < 0.0001,
			"lean %.4f" % during)
	e.attack_motion_active = false
	await _wait(0.5)


func _section_kill() -> void:
	var e := _enemies[2]
	e.stats.health = 5
	var imp := _spawns(e, "hit_fx_impact")
	var targets: Array[Node] = [e]
	# Not single-target, so the kill resolves now instead of riding the die strike.
	Global.last_attack_card_played_frame = Engine.get_process_frames()
	Global.last_attack_card_single_target = false
	var eff := DamageEffect.new()
	eff.amount = 12
	eff.sound = HIT_SOUND
	eff.execute(targets)
	_check("K1 the killing blow draws the impact", _spawns(e, "hit_fx_impact") == imp + 1)
	await _wait(0.3)
	_check("K2 the dead enemy has left the enemies group", not e.is_in_group("enemies"))
	await _wait(2.0)
	_check("K3 the corpse (and its effects) are freed", not is_instance_valid(e))


func _section_cleanup() -> void:
	await _wait(1.6)
	var left := 0
	for g in FX_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				left += 1
	_check("L1 no hit effect node outlives its hit (no manual cleanup anywhere in this run)",
			left == 0, "left %d" % left)
