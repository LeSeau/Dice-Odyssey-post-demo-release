extends Node

# ENEMY HUD vs HAND/BUTTONS OVERLAP AUDIT (2026-08-27).
#
# Julien: "This keeps happening; status icons overlapping things, in this case cards."
# The 2026-08-25 pass solved status-row-vs-End-Turn by moving the button DOWN to y581..643,
# but its own ledger says the HUD stack still reaches y579 at worst while the card fan's
# top sits at y561 in its centre columns - the fan collision was left open. This harness
# measures that collision exactly, instead of reasoning about it:
#
#   * boots every fight in battles/ inside the REAL battle.tscn
#   * plants probe statuses on every enemy AND the player (a row that doesn't exist
#     measures nothing)
#   * deals hands of 5 / 8 / 10 cards and reads the TRUE axis-aligned bbox of every
#     resting card (cards are rotated by the fan - the 4 transformed corners are used,
#     never the unrotated rect)
#   * reports, per enemy: bar rect, status row rect, feet line, and the deepest
#     penetration of the row/bar into any resting card, End Turn, or the pile buttons -
#     plus the upward shift that would clear it and whether that shift keeps the feet
#     on the painted floor (starts ~y510 in every background).
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_status_overlap.tscn \
#       --rendering-driver opengl3 --position 2000,2000 > overlap_out.txt 2>&1
# Env: OVERLAP_ONLY=substring   OVERLAP_ACT=2   OVERLAP_HANDS=5,8,10   OVERLAP_RENDER=1

const VIEW := Vector2(1280, 720)
# Painted floor starts here in every combat background (act-2 library's furniture band is
# the tightest at ~y505-510 on the right) - feet above this line read as floating on air.
const FLOOR_START_Y := 510.0
# A row is "clear" of a card with at least this much daylight.
const MARGIN := 2.0
# Contract margin: rows must clear the measured fan-top bucket by this much. The runtime
# tripwire (Enemy.FAN_KEEPOUT_BANDS) fires at 0 margin, so anything passing here has a
# real cushion before the tripwire would ever warn.
const BAND_MARGIN := 4.0

var _fights := []
var _pool_names := {}
var _rows := []
var _violations := []
var hands_drawn := 0
var _vp: SubViewport
var _hand_counts: Array[int] = [5, 8, 10]
var _bands_checked := false


func _ready() -> void:
	await _run()
	get_tree().quit()


func _await_until(cond: Callable, t: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _collect_fights() -> void:
	var pool = load("res://battles/battle_stats_pool.tres")
	if pool != null and "pool" in pool:
		for bs in pool.pool:
			if bs != null:
				_pool_names[bs.resource_path.get_file().get_basename()] = true
	var dir := DirAccess.open("res://battles")
	var only := OS.get_environment("OVERLAP_ONLY")
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		if f.begins_with("battle_stats_pool"):
			continue
		if only != "" and not f.contains(only):
			continue
		_fights.append("res://battles/" + f)
	_fights.sort()


func _run() -> void:
	var hands_env := OS.get_environment("OVERLAP_HANDS")
	if hands_env != "":
		_hand_counts.clear()
		for part in hands_env.split(","):
			_hand_counts.append(int(part))
	if OS.get_environment("OVERLAP_ACT") == "2":
		Global.current_act = 2
	Events.player_hand_drawn.connect(func() -> void: hands_drawn += 1)
	_collect_fights()
	print("[overlap] auditing %d fights, hand sizes %s, act %d"
		% [_fights.size(), str(_hand_counts), Global.current_act])
	for fight in _fights:
		await _audit_fight(fight)
	_report()


# True visual rect of a Control under any rotation/scale: aabb of the 4 corners.
func _vis_aabb(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	var pts := [xf * Vector2.ZERO, xf * Vector2(c.size.x, 0),
		xf * Vector2(0, c.size.y), xf * c.size]
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)


# Cards are ROTATED by the fan (up to +-7.5deg). Their axis-aligned bbox over-reaches by up
# to ~18px at the tilted corners, which made every needed shift look floor-illegal on the
# first run of this harness - so collisions are measured against the true rotated QUAD.
func _card_quads(hand: Node) -> Array:
	var out := []
	for card in hand.get_children():
		if card is Control and (card as Control).visible:
			var c := card as Control
			var xf := c.get_global_transform()
			out.append(PackedVector2Array([xf * Vector2.ZERO, xf * Vector2(c.size.x, 0),
				xf * c.size, xf * Vector2(0, c.size.y)]))
	return out


# Min y (visual TOP) of a convex quad clipped to the vertical strip [x0,x1].
# INF when the quad has no columns in the strip.
func _quad_top_in_strip(quad: PackedVector2Array, x0: float, x1: float) -> float:
	var poly := quad
	for clip_right in [false, true]:
		var next := PackedVector2Array()
		var n := poly.size()
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			var a_in: bool = (a.x <= x1) if clip_right else (a.x >= x0)
			var b_in: bool = (b.x <= x1) if clip_right else (b.x >= x0)
			var edge_x := x1 if clip_right else x0
			if a_in:
				next.append(a)
			if a_in != b_in and absf(b.x - a.x) > 0.0001:
				var t := (edge_x - a.x) / (b.x - a.x)
				next.append(a.lerp(b, t))
		poly = next
		if poly.is_empty():
			return INF
	var top := INF
	for p in poly:
		top = minf(top, p.y)
	return top


# Deepest vertical penetration of rect `r`'s bottom edge past any quad's top boundary,
# measured only over the columns they actually share.
func _worst_hit(r: Rect2, quads: Array) -> Dictionary:
	var worst := {"depth": 0.0}
	for q in quads:
		var top := _quad_top_in_strip(q, r.position.x, r.position.x + r.size.x)
		if top == INF:
			continue
		var depth: float = r.position.y + r.size.y - top
		# Only count real overlap: the rect must actually reach past the quad's top
		# AND start above the quad's bottom (a rect fully below a card is not "overlap
		# a shift could fix" - it does not happen in practice, rows sit above cards).
		if depth >= 1.0 and depth > worst["depth"]:
			worst = {"depth": depth}
	return worst


func _rect_quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0),
		r.end, r.position + Vector2(0, r.size.y)])


func _audit_fight(fight_path: String) -> void:
	var stats: BattleStats = load(fight_path)
	if stats == null or stats.enemies == null:
		return

	_vp = SubViewport.new()
	_vp.size = Vector2i(VIEW)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var battle: Battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	_vp.add_child(battle)
	var rh: RelicHandler = (load("res://scenes/relic_handler/relic_handler.tscn") as PackedScene).instantiate()
	var host := Control.new()
	host.size = Vector2(400, 80)
	_vp.add_child(host)
	host.add_child(rh)

	var warrior: CharacterStats = load("res://characters/warrior/warrior.tres")
	battle.char_stats = warrior.create_instance()
	battle.relics = rh
	battle.battle_stats = stats
	battle.act_tier = stats.battle_tier

	var d0 := hands_drawn
	battle.start_battle()
	await _await_until(func() -> bool: return hands_drawn > d0, 20.0)

	var muscle_res := load("res://statuses/muscle.tres")
	var weak_res := load("res://statuses/weak.tres")
	var exposed_res := load("res://statuses/exposed.tres")
	for child in battle.enemy_handler.get_children():
		if not (child is Enemy) or child.is_queued_for_deletion():
			continue
		var m = muscle_res.duplicate()
		m.stacks = 3
		child.status_handler.add_status(m)
		var w = weak_res.duplicate()
		w.stacks = 2
		child.status_handler.add_status(w)
		var x = exposed_res.duplicate()
		x.stacks = 2
		child.status_handler.add_status(x)
	var player := battle.get_node_or_null("Player")
	if player != null and player.has_node("StatusHandler"):
		var pw = weak_res.duplicate()
		pw.stacks = 2
		player.status_handler.add_status(pw)
		var pm = muscle_res.duplicate()
		pm.stacks = 3
		player.status_handler.add_status(pm)
	for i in 15:
		await get_tree().process_frame

	var fight_name := fight_path.get_file().get_basename()
	var hand := battle.find_child("Hand", true, false)
	var end_turn := battle.find_child("EndTurnButton", true, false) as Control
	var et_rect := end_turn.get_global_rect() if end_turn != null else Rect2()

	# --- measure the enemy + player HUD once (independent of hand size) -----------
	var subjects := []
	for child in battle.enemy_handler.get_children():
		if not (child is Enemy) or child.is_queued_for_deletion():
			continue
		var e := child as Enemy
		var bar := e.stats_ui.get_node_or_null("Health/HealthBar") as Control
		if bar == null:
			continue
		# stats_ui.position.y IS the feet line (+ any authored downward nudge) in
		# enemy-local space - transform it out for the on-screen feet.
		var feet_y: float = e.to_global(Vector2(0.0, e.stats_ui.position.y)).y
		subjects.append({
			"name": e._display_name, "bar": _vis_aabb(bar),
			"row": _vis_aabb(e.status_handler), "feet": feet_y, "is_player": false,
		})
	if player != null and player.has_node("StatusHandler"):
		var p_bar := player.stats_ui.get_node_or_null("Health/HealthBar") as Control
		if p_bar != null:
			subjects.append({
				"name": "PLAYER", "bar": _vis_aabb(p_bar),
				"row": _vis_aabb(player.status_handler),
				"feet": player.to_global(Vector2(0.0, player.stats_ui.position.y)).y,
				"is_player": true,
			})

	# --- deal each hand size in turn and collect card boxes -----------------------
	var fan_by_count := {}
	for target_count in _hand_counts:
		# Bounded: a broken deal (resource failures upstream) must fail the audit loudly,
		# never hang it - the first run of this harness hung exactly here.
		var attempts := 0
		while hand.get_child_count() < target_count and attempts < 40:
			battle.player_handler.draw_card()
			attempts += 1
			await get_tree().process_frame
		if hand.get_child_count() < target_count:
			print("   [overlap] !! could only deal %d/%d cards - deck broken?"
				% [hand.get_child_count(), target_count])
		for i in 12:
			await get_tree().process_frame
		fan_by_count[target_count] = _card_quads(hand)
		if OS.get_environment("OVERLAP_DEBUG") != "":
			var hr := (hand as Control).get_global_rect()
			print("   [dbg] hand rect=(%.0f,%.0f %.0fx%.0f) count=%d"
				% [hr.position.x, hr.position.y, hr.size.x, hr.size.y, target_count])
			for card in hand.get_children():
				if card is Control:
					var c := card as Control
					print("      card pos=(%.0f,%.0f) rot=%.1f scale=(%.2f,%.2f) size=(%.0f,%.0f) gpos=(%.0f,%.0f)"
						% [c.position.x, c.position.y, c.rotation_degrees, c.scale.x, c.scale.y,
							c.size.x, c.size.y, c.global_position.x, c.global_position.y])

	# --- fan profile (worst TRUE card top per 50px x-bucket, all counts merged) ---
	# 50px buckets, matching Enemy.FAN_KEEPOUT_BANDS: the fan slope is ~6px/100px, so
	# coarser buckets over-ask fights for room the floor line cannot give.
	var profile := {}
	for target_count in _hand_counts:
		for q in fan_by_count[target_count]:
			for b in range(0, 26):
				var top := _quad_top_in_strip(q, b * 50.0, b * 50.0 + 50.0)
				if top == INF:
					continue
				if not profile.has(b) or top < profile[b]:
					profile[b] = top
	var prof_line := "   fan tops: "
	var buckets := profile.keys()
	buckets.sort()
	for b in buckets:
		prof_line += "x%d:%d " % [b * 50, int(profile[b])]
	print("[overlap] %s" % fight_name)
	print(prof_line)

	# --- keep-out contract staleness check (once - the fan is identical every fight) ----
	# Enemy.FAN_KEEPOUT_BANDS is the baked worst-case table the runtime tripwire uses.
	# If the live fan reaches HIGHER than a band says (hand retuned, card resized...), the
	# contract silently under-protects - fail loudly and demand a re-bake.
	if not _bands_checked:
		_bands_checked = true
		for b in buckets:
			var bucket_center: float = b * 50.0 + 25.0
			for band in Enemy.FAN_KEEPOUT_BANDS:
				if bucket_center >= band[0] and bucket_center < band[1] \
						and profile[b] < band[2] - 0.5:
					_violations.append(
						"BAND STALE: cards reach y%.0f at x%d but Enemy.FAN_KEEPOUT_BANDS says y%.0f for x%.0f-%.0f - re-bake the table from this run's fan tops"
						% [profile[b], b * 50, band[2], band[0], band[1]])

	# --- collisions ----------------------------------------------------------------
	for s in subjects:
		var row: Rect2 = s["row"]
		var bar: Rect2 = s["bar"]

		# Ground truth: deepest penetration into an actual resting card, any hand size.
		var worst := {"depth": 0.0, "count": 0, "what": ""}
		for target_count in _hand_counts:
			var cards: Array = fan_by_count[target_count]
			var hit: Dictionary = _worst_hit(row, cards)
			if hit["depth"] > worst["depth"]:
				worst = {"depth": hit["depth"], "count": target_count, "what": "cards"}
			var bar_hit: Dictionary = _worst_hit(bar, cards)
			if bar_hit["depth"] > worst["depth"]:
				worst = {"depth": bar_hit["depth"], "count": target_count, "what": "cards(BAR)"}
		var et_hit: Dictionary = _worst_hit(row, [_rect_quad(et_rect)])
		if et_hit["depth"] > worst["depth"]:
			worst = {"depth": et_hit["depth"], "count": 0, "what": "END TURN"}

		# THE pass/fail criterion: the CONTRACT - the row must clear the live measured
		# fan-top profile (same 50px buckets the runtime tripwire mirrors) by BAND_MARGIN.
		# Stricter than the ground truth by construction (bucket min + margin), which is
		# the point: a fight that only just misses today's cards is one art tweak away
		# from the next screenshot.
		var b0 := int(row.position.x / 50.0)
		var b1 := int((row.position.x + row.size.x) / 50.0)
		var band_req := INF
		for b in range(b0, b1 + 1):
			if profile.has(b):
				band_req = minf(band_req, profile[b])
		var band_short: float = 0.0
		if band_req != INF:
			band_short = maxf(row.position.y + row.size.y - (band_req - BAND_MARGIN), 0.0)
		if et_hit["depth"] > 0.0:
			band_short = maxf(band_short, et_hit["depth"] + BAND_MARGIN)

		var feet_after: float = s["feet"] - band_short
		var legal: bool = feet_after >= FLOOR_START_Y or s["is_player"]
		var tag := ""
		if band_short > 0.0:
			tag = "  <<< SHORT %.0fpx (true overlap %.0fpx into %s at hand %d) raise=%.0f feet_after=%.0f%s" % [
				band_short, worst["depth"], worst["what"], worst["count"], band_short, feet_after,
				"" if legal else "  [WOULD FLOAT]"]
			var reach := "" if _pool_names.has(fight_name) else "  [UNREACHABLE FIGHT]"
			_violations.append("%s / %s: %.0fpx short of contract (true overlap %.0fpx, hand %d)%s"
				% [fight_name, s["name"], band_short, worst["depth"], worst["count"], reach])
		print("   %-16s feet=%4.0f bar=(%4.0f,%4.0f %3.0fx%2.0f) row=(%4.0f,%4.0f %3.0fx%2.0f)%s"
			% [s["name"], s["feet"], bar.position.x, bar.position.y, bar.size.x, bar.size.y,
				row.position.x, row.position.y, row.size.x, row.size.y, tag])
		_rows.append({"fight": fight_name, "name": s["name"], "depth": band_short,
			"feet": s["feet"], "row": row})

	if OS.get_environment("OVERLAP_RENDER") != "":
		DirAccess.make_dir_recursive_absolute("res://overlap_render")
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.save_png("res://overlap_render/%s_act%d.png" % [fight_name, Global.current_act])

	_vp.queue_free()
	for i in 4:
		await get_tree().process_frame


func _report() -> void:
	print("\n================ HUD vs HAND OVERLAP ================")
	var bad := 0
	var deepest := 0.0
	var deepest_who := ""
	for r in _rows:
		if r["depth"] > 0.0:
			bad += 1
			if r["depth"] > deepest:
				deepest = r["depth"]
				deepest_who = "%s / %s" % [r["fight"], r["name"]]
	for v in _violations:
		print("  [FAIL] ", v)
	print("\n%d subjects measured, %d overlapping, deepest %.0fpx (%s)"
		% [_rows.size(), bad, deepest, deepest_who])
