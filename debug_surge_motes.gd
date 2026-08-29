extends Node

# Harness for the two 2026-08-25 die-cluster additions:
#   A. Surge motes  - sparks leaking off the central die while SURGE is up.
#   B. Armed socket  - the empty Red socket while the Armageddon blessing is up.
#
# The load-bearing checks are A3 and B3.
#   A3 asks whether the density actually scales with the stack count. That is the exact class
#      of bug the charge gust shipped with: a per-count multiplier pushed against a uniform's
#      ceiling and every count rendered identically, in silence.
#   B3 asks whether charged_card_texture is still null after arming. roll_dice() and
#      _fire_socketless_red() both use that texture as their "a card is socketed" test, so
#      putting an Armageddon face in the art slot would silently kill the blessing while
#      looking perfect in a screenshot.
#
# Run (checks + stills):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_surge_motes.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Env:
#   SURGE_MOTES_OUT   absolute output dir (default user://surge_motes)

const VIEW := Vector2i(1280, 720)
const DIE_POS := Vector2(521, 294)
# Mirrors battle.tscn's DiceInterface placement. The row is what the mote clearance band
# exists for, so it has to be on stage at its real rect.
const ROW_POS := Vector2(514, 214)
const ROW_SIZE := Vector2(160, 72)
# Sampling is by SECONDS, never by frame count. The harness scene is nearly empty and runs at
# well over 60fps, so an earlier frame-based window collapsed to ~1.3s of game time and only
# ever caught 2-3 spawns - enough to pass a "denser?" check on noise alone.
const SAMPLE_SECONDS := 4.5
# Surge 4 spawns every 0.28s against Surge 1's 0.55s, so the honest expectation is ~1.95x.
# Demanding a real ratio (not merely ">") is what makes this catch a silently capped multiplier.
const DENSITY_RATIO_MIN := 1.5
const SURGE_MOTE_ALPHA_FLOOR := 0.30  # dice.gd tweens each mote to at least 0.36
const LIT_THRESHOLD := 0.04  # summed |RGB| delta that counts a sampled pixel as lit
# dice.gd clamps every rise so a mote tops out this far above the die art; the row it protects
# sits further up still, and A4 asserts both halves of that.
const MOTE_HEADROOM := 18.0

var vp: SubViewport
var dice: Control
var dice_interface: Control
var out_dir := ""
var checks := 0
var fails := 0


func _check(cname: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[surge-motes] %s %s %s" % ["PASS" if ok else "FAIL", cname, detail])


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _save(img: Image, fname: String) -> void:
	img.save_png("%s/%s" % [out_dir, fname])


func _live_motes() -> Array[Control]:
	var out: Array[Control] = []
	for node in get_tree().get_nodes_in_group("surge_mote"):
		if node is Control and is_instance_valid(node):
			out.append(node)
	return out


# Watches the die for `seconds` of game time, returning how many DISTINCT motes appeared, the
# highest point (smallest root-local y) any of them reached over its whole flight, and the peak
# brightness of the die region while they were up.
func _watch_motes(seconds: float, region: Rect2i) -> Dictionary:
	var seen := {}
	var highest := INF
	var peak_lum := 0.0
	var peak_alpha := 0.0
	var max_concurrent := 0
	var elapsed := 0.0
	while elapsed < seconds:
		var live := _live_motes()
		max_concurrent = maxi(max_concurrent, live.size())
		for mote in live:
			seen[mote.get_instance_id()] = true
			highest = minf(highest, mote.position.y)
			peak_alpha = maxf(peak_alpha, mote.modulate.a)
		# Sampled every frame rather than from one arbitrary still: motes fade in and out, so a
		# single grab can easily land between two of them and read as "no effect at all".
		if region.size.x > 0:
			peak_lum = maxf(peak_lum, _mean_brightness(await _grab(), region))
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	return {
		"count": seen.size(), "highest": highest, "peak_lum": peak_lum,
		"peak_alpha": peak_alpha, "max_concurrent": max_concurrent,
	}


func _mean_brightness(img: Image, rect: Rect2i) -> float:
	var total := 0.0
	var n := 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			var c := img.get_pixel(x, y)
			total += c.r + c.g + c.b
			n += 1
	return total / float(maxi(n, 1))


# Sampled pixels that differ from a calm baseline by more than `threshold`. The region MEAN is
# useless for this: a handful of 15px sparks over a 140x140 panel dilutes to nothing (the same
# trap that hid the charge ring behind a "below the floor" average). Counting lit AREA against
# a quiet frame is what actually measures a small bright thing.
func _lit_area(img: Image, base: Image, rect: Rect2i, threshold: float) -> int:
	var lit := 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			var c := img.get_pixel(x, y)
			var b := base.get_pixel(x, y)
			var d: float = absf(c.r - b.r) + absf(c.g - b.g) + absf(c.b - b.b)
			if d > threshold:
				lit += 1
	return lit


# Peak lit area over `seconds`, so the sample cannot land in the gap between two motes.
func _peak_lit_area(seconds: float, base: Image, rect: Rect2i) -> int:
	var peak := 0
	var elapsed := 0.0
	while elapsed < seconds:
		peak = maxi(peak, _lit_area(await _grab(), base, rect, LIT_THRESHOLD))
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	return peak


func _build_stage(parent: Node) -> void:
	Global.blue_dice_max_amount = 2
	Global.blue_dice_current_amount = 2
	Global.red_dice_max_amount = 1
	Global.red_dice_current_amount = 1

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(VIEW)
	bg.modulate = Color(0.74, 0.74, 0.74)
	parent.add_child(bg)

	dice_interface = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	parent.add_child(dice_interface)
	dice_interface.position = ROW_POS
	dice_interface.size = ROW_SIZE
	# battle.tscn puts its instance in this group; dice.gd reads the group to derive the
	# emanation shader's row-clearance bounds, and the row is the thing motes must clear.
	dice_interface.add_to_group("dice_interface")

	dice = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	parent.add_child(dice)
	dice.position = DIE_POS
	dice.size = Vector2(144, 144)


func _ready() -> void:
	Global.tutorial_on = true  # mute achievement toasts while the harness fakes game events
	out_dir = OS.get_environment("SURGE_MOTES_OUT")
	if out_dir == "":
		out_dir = "user://surge_motes"
	DirAccess.make_dir_recursive_absolute(out_dir)

	Global.surge_amount = 0
	Global.surge_expiring = 0
	Global.socketless_red = false
	Global.socketless_red_strength = 0

	vp = SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_build_stage(vp)
	await _settle(30)

	dice._on_active_dice_changed("blue")
	await _settle(20)

	await _section_motes()
	await _section_armed_socket()

	print("[surge-motes] --- %d checks, %d fail ---" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------------------------------
# A. Surge motes
# ---------------------------------------------------------------------------------------
func _section_motes() -> void:
	var die_rect: Rect2 = dice._die_rest_rect
	_check("A0 die rest rect captured", die_rect.size.x > 100.0 and die_rect.size.y > 100.0,
			str(die_rect))

	var region := Rect2i(int(DIE_POS.x + die_rect.position.x), int(DIE_POS.y + die_rect.position.y),
			int(die_rect.size.x), int(die_rect.size.y))

	# --- A1 negative control: nothing should spawn at Surge 0 --------------------------
	var idle := await _watch_motes(SAMPLE_SECONDS, region)
	var base_lum: float = float(idle["peak_lum"])
	_check("A1 no motes at Surge 0", int(idle["count"]) == 0, "count=%d" % int(idle["count"]))

	# --- A2/A3 density scales with the stack count --------------------------------------
	Global.surge_amount = 1
	var one := await _watch_motes(SAMPLE_SECONDS, region)
	_save(await _grab(), "motes_surge1.png")
	_check("A2 motes spawn at Surge 1", int(one["count"]) > 0, "count=%d" % int(one["count"]))

	Global.surge_amount = 4
	var four := await _watch_motes(SAMPLE_SECONDS, region)
	_save(await _grab(), "motes_surge4.png")
	var ratio := float(four["count"]) / maxf(float(one["count"]), 1.0)
	_check("A3 Surge 4 is measurably denser than Surge 1", ratio >= DENSITY_RATIO_MIN,
			"surge1=%d surge4=%d ratio=%.2f (min %.2f)" % [
					int(one["count"]), int(four["count"]), ratio, DENSITY_RATIO_MIN])

	# --- A4 clearance, both halves of the contract --------------------------------------
	# The slot row draws at z_index 5, so a mote that drifts into it does not overlap the tray,
	# it vanishes behind an opaque plate mid-flight. dice.gd clamps every rise to a ceiling; so
	# check (a) no mote ever beats that ceiling and (b) the ceiling really is clear of the row.
	var ceiling: float = die_rect.position.y - MOTE_HEADROOM
	var row_bottom_local: float = (ROW_POS.y + ROW_SIZE.y) - DIE_POS.y
	var highest: float = minf(float(one["highest"]), float(four["highest"]))
	_check("A4a no mote beats the rise clamp", highest >= ceiling - 0.5,
			"highest=%.1f ceiling=%.1f" % [highest, ceiling])
	_check("A4b the clamp clears the slot row", ceiling - row_bottom_local >= 15.0,
			"ceiling=%.1f row_bottom=%.1f gap=%.1f" % [
					ceiling, row_bottom_local, ceiling - row_bottom_local])

	# --- A5 warm-shifted tint, not the raw accent ---------------------------------------
	# A spark in the die's own accent is invisible inside the emanation field of that same
	# accent - the exact way the charge gust failed on the same day.
	var accent := DicePalette.accent("blue")
	var motes := _live_motes()
	var tinted := false
	var dist := 0.0
	if not motes.is_empty():
		var m: Color = motes[0].modulate
		dist = absf(m.r - accent.r) + absf(m.g - accent.g) + absf(m.b - accent.b)
		tinted = dist > 0.15 and m.r > accent.r
	_check("A5 mote tint is warm-shifted off the accent", tinted,
			"dist=%.2f (n=%d)" % [dist, motes.size()])

	# --- A6 motes must not eat hovers ---------------------------------------------------
	var all_ignore := not motes.is_empty()
	for m2 in motes:
		if m2.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			all_ignore = false
	_check("A6 motes are MOUSE_FILTER_IGNORE", all_ignore, "n=%d" % motes.size())

	print("[surge-motes] .. surge4 window: concurrent=%d peak_alpha=%.2f mean_lum=%.4f" % [
			int(four["max_concurrent"]), float(four["peak_alpha"]), float(four["peak_lum"])])
	_check("A6b motes reach a real alpha", float(four["peak_alpha"]) >= SURGE_MOTE_ALPHA_FLOOR,
			"peak_alpha=%.2f" % float(four["peak_alpha"]))

	# --- A7 they are actually VISIBLE, by lit AREA against a calm frame -----------------
	# The noise floor is measured, not assumed: the emanation shader animates every frame, so
	# a quiet die still differs from its own baseline a little. The signal has to clear that.
	Global.surge_amount = 0
	await _settle(120)  # let every in-flight mote die before taking the calm frame
	var calm := await _grab()
	var noise := await _peak_lit_area(1.5, calm, region)
	Global.surge_amount = 4
	# Ground truth before trusting any aggregate: find a live mote, and read the actual pixel
	# under its centre against the calm frame. If this shows no change the mote is not drawing
	# where its transform says it is, and every area metric downstream is measuring the shader.
	await _settle(60)
	var probe := "no live mote found"
	for m3 in _live_motes():
		if m3.modulate.a > 0.4:
			var r := m3.get_global_rect()
			var px := Vector2i(r.get_center())
			var now := await _grab()
			var tex: Texture2D = (m3 as TextureRect).texture
			probe = "rect=%s a=%.2f vis=%s tex=%s texsize=%s mat=%s expand=%d stretch=%d | now=%s calm=%s" % [
					str(r), m3.modulate.a, str(m3.is_visible_in_tree()),
					"null" if tex == null else tex.get_class(),
					"n/a" if tex == null else str(tex.get_size()),
					"null" if m3.material == null else m3.material.get_class(),
					(m3 as TextureRect).expand_mode, (m3 as TextureRect).stretch_mode,
					str(now.get_pixel(px.x, px.y)), str(calm.get_pixel(px.x, px.y))]
			now.get_region(Rect2i(px.x - 40, px.y - 40, 80, 80)) \
					.save_png("%s/probe_mote_crop.png" % out_dir)
			break
	print("[surge-motes] .. mote pixel probe: %s" % probe)

	var signal_area := await _peak_lit_area(SAMPLE_SECONDS, calm, region)
	_check("A7 motes light a real area of the die region",
			signal_area >= maxi(noise * 3, 25),
			"lit=%d px  noise_floor=%d px (need >= %d)" % [
					signal_area, noise, maxi(noise * 3, 25)])
	_save(await _grab(), "motes_surge4_lit.png")

	Global.surge_amount = 0


# ---------------------------------------------------------------------------------------
# B. Armed socket (Armageddon)
# ---------------------------------------------------------------------------------------
func _section_armed_socket() -> void:
	# --- B1 baseline: no blessing, the socket keeps its normal placeholder --------------
	Global.socketless_red = false
	dice._on_active_dice_changed("red")
	await _settle(20)
	_check("B1 unarmed socket keeps its placeholder",
			dice.requirement_label.text == "Drop a card"
			and dice.charged_card_description.text.contains("Place a card here"),
			"ribbon=%s" % dice.requirement_label.text)
	_save(await _grab(), "socket_unarmed.png")

	# --- B2 arm it the way the card does, then switch to Red ----------------------------
	dice._on_active_dice_changed("blue")
	await _settle(10)
	Global.socketless_red = true  # what armageddon.gd sets
	dice._on_active_dice_changed("red")
	await _settle(30)
	var desc: String = dice.charged_card_description.text
	_check("B2 armed socket renames the title", dice.title.text == "Armageddon",
			"title=%s" % dice.title.text)
	_check("B2 armed socket ribbon says no card is needed",
			dice.requirement_label.text == "No card needed",
			"ribbon=%s" % dice.requirement_label.text)
	_check("B2 armed socket describes the socketless roll",
			desc.contains("ALL enemies") and desc.contains("power_glyph"),
			desc.substr(0, 90))
	_save(await _grab(), "socket_armed.png")

	# --- B3 THE footgun: the art slot must stay empty -----------------------------------
	# roll_dice() and _fire_socketless_red() both branch on this texture. A card face here
	# would look right and silently disable the whole blessing.
	_check("B3 charged_card_texture is still null while armed",
			dice.charged_card_texture.texture == null)
	_check("B3 socketless roll path is still reachable",
			Global.socketless_red and dice.charged_card_texture.texture == null
			and not is_instance_valid(dice.socketed_card_ui))

	# --- B3b the art overlay is a SEPARATE node from the socket's real art slot ---------
	# Conditional on the texture actually being importable: this worktree's .godot cache has no
	# .ctex for socketless_red.png, and dice.gd degrades to "no overlay" rather than crashing.
	var icon := dice.panel.get_node_or_null("ArmedSocketIcon") as TextureRect
	# Gate on a real load, not ResourceLoader.exists() - exists() reports the path/.import pair
	# and still returns true when the imported .ctex is missing.
	if load("res://socketless_red.png") != null:
		_check("B3b armed art overlay is shown", icon != null and icon.visible)
	else:
		print("[surge-motes] SKIP B3b - socketless_red.png has no .ctex in this worktree")

	# --- B4 the description fits the slot -----------------------------------------------
	var avail: float = dice.description_panel.size.y
	var used: float = dice.charged_card_description.get_content_height()
	_check("B4 armed description fits the panel", used <= avail,
			"used=%.0f avail=%.0f" % [used, avail])

	# --- B5 the title fits the banner ---------------------------------------------------
	var settings: LabelSettings = dice.title.label_settings
	var title_w: float = settings.font.get_string_size(
			dice.title.text, HORIZONTAL_ALIGNMENT_CENTER, -1, settings.font_size).x
	_check("B5 armed title fits the banner width", title_w <= dice.title.size.x,
			"text=%.0fpx label=%.0fpx" % [title_w, dice.title.size.x])

	# --- B6 Armageddon+ says it grants Strength, and still fits --------------------------
	Global.socketless_red_strength = 1
	dice._set_socket_empty()
	await _settle(10)
	var desc_plus: String = dice.charged_card_description.text
	var used_plus: float = dice.charged_card_description.get_content_height()
	_check("B6 plus variant mentions Strength", desc_plus.contains("Strength"),
			desc_plus.substr(0, 90))
	_check("B6 plus description still fits", used_plus <= dice.description_panel.size.y,
			"used=%.0f avail=%.0f" % [used_plus, dice.description_panel.size.y])
	_save(await _grab(), "socket_armed_plus.png")
	Global.socketless_red_strength = 0

	# --- B7 leaving Red and coming back re-arms -----------------------------------------
	dice._on_active_dice_changed("blue")
	await _settle(10)
	dice._on_active_dice_changed("red")
	await _settle(20)
	_check("B7 socket re-arms after a type round-trip",
			dice.requirement_label.text == "No card needed")

	# --- B8 negative control: drop the blessing, the socket goes inert again ------------
	Global.socketless_red = false
	dice._set_socket_empty()
	await _settle(5)
	_check("B8 clearing the blessing restores the placeholder",
			dice.requirement_label.text == "Drop a card" and dice.title.text == "?",
			"ribbon=%s title=%s" % [dice.requirement_label.text, dice.title.text])
	var icon2 := dice.panel.get_node_or_null("ArmedSocketIcon") as TextureRect
	_check("B8b armed art overlay is hidden again", icon2 == null or not icon2.visible)
	_save(await _grab(), "socket_disarmed.png")
