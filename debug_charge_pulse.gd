extends Node

# Measurement + render harness for the charge pulse (round 2, 2026-08-25 - the "gust").
# Boots the die cluster over the act-1 background, emits REAL Events.dice_charged signals.
#
# The load-bearing check is A4/A5: does the energy actually LEAVE the die? Round 1 failed
# exactly there - its band was as thick as its whole travel and the aura flare inflated
# over it, so it brightened in place and faded (a breath). So the harness measures a radial
# brightness profile in the clear corridors either side of the die and demands that the
# outer band overtake the inner one partway through. A pulse that only pulses fails.
#
# Run (checks):
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_charge_pulse.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Run (motion strip for one variant):
#   ... same, plus --write-movie <dir>/f.png --fixed-fps 30 --resolution 1280x720
#   with CHARGE_PULSE_MOVIE=1 (realtime PNG saving compresses tween motion - the
#   documented capture trap; assert truth is always the run WITHOUT --write-movie)
# Env:
#   CHARGE_PULSE_OUT    absolute output dir (default user://charge_pulse)
#   CHARGE_PULSE_MOVIE  1 = visual pass, no checks
#   CHARGE_PULSE_MODE   0 gust (default) | 1 gust+ring | 2 punchier | 3 none (baseline)
#   CHARGE_PULSE_ROW_DY shift the dice-type row up by N px (row-clearance comparison)

const VIEW := Vector2i(1280, 720)
const DIE_POS := Vector2(521, 294)
const DIE_CENTER := Vector2(598, 371)  # DIE_POS + panel half (77, 77)

var vp: SubViewport
var dice: Control
var dice_interface: Control
var out_dir := ""
var checks := 0
var fails := 0


func _check(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[charge-pulse] %s %s %s" % ["PASS" if ok else "FAIL", name, detail])


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


# Mean |frame - baseline| by distance from the die centre, sampled ONLY in the clear
# horizontal corridors left and right of the die: the slot row sits above and the opaque
# ROLL button below, so both would contaminate a full-circle sample.
func _radial_profile(img: Image, base: Image) -> Dictionary:
	var sums := {}
	var counts := {}
	var cx := int(DIE_CENTER.x)
	var cy := int(DIE_CENTER.y)
	for y in range(cy - 30, cy + 31, 2):
		for r in range(60, 170, 2):
			for s in [-1, 1]:
				var x: int = cx + s * r
				var c := img.get_pixel(x, y)
				var b := base.get_pixel(x, y)
				var dv: float = absf(c.r - b.r) + absf(c.g - b.g) + absf(c.b - b.b)
				var key: int = (r / 10) * 10
				sums[key] = float(sums.get(key, 0.0)) + dv
				counts[key] = int(counts.get(key, 0)) + 1
	var out := {}
	for k: int in sums:
		out[k] = float(sums[k]) / float(counts[k])
	return out


func _band_mean(prof: Dictionary, r0: int, r1: int) -> float:
	var s := 0.0
	var n := 0
	for k: int in prof:
		if k >= r0 and k <= r1:
			s += float(prof[k])
			n += 1
	return s / float(maxi(n, 1))


func _build_stage(parent: Node) -> void:
	Global.blue_dice_max_amount = 2
	Global.blue_dice_current_amount = 2
	Global.red_dice_max_amount = 1
	Global.red_dice_current_amount = 1
	Global.magma_dice_max_amount = 1
	Global.magma_dice_current_amount = 1
	Global.evil_dice_max_amount = 1
	Global.evil_dice_current_amount = 1

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(VIEW)
	bg.modulate = Color(0.74, 0.74, 0.74)
	parent.add_child(bg)

	var row_dy := float(int(OS.get_environment("CHARGE_PULSE_ROW_DY")))
	dice_interface = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	parent.add_child(dice_interface)
	dice_interface.position = Vector2(514, 214 - row_dy)
	dice_interface.size = Vector2(160, 72)
	# battle.tscn puts its instance in this group; a bare instantiate is not in it, and
	# dice.gd reads the group to derive the shader's row-clearance bounds.
	dice_interface.add_to_group("dice_interface")

	dice = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	parent.add_child(dice)
	dice.position = DIE_POS
	dice.size = Vector2(144, 144)
	dice.charge_pulse_mode = int(OS.get_environment("CHARGE_PULSE_MODE"))


func _set_power(value: int, history: Array) -> void:
	Global.roll_value = value
	Global.roll_history = history
	dice.update_roll_history_ui()
	dice._set_power_text(value)
	dice._update_dice_aura_charge()


func _ready() -> void:
	Global.tutorial_on = true  # mute achievements while the harness fakes game events
	out_dir = OS.get_environment("CHARGE_PULSE_OUT")
	if out_dir == "":
		out_dir = "user://charge_pulse"
	DirAccess.make_dir_recursive_absolute(out_dir)

	if OS.get_environment("CHARGE_PULSE_MOVIE") != "":
		await _run_movie_pass()
		return

	vp = SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_build_stage(vp)

	await _settle(30)
	# Measurement scenarios run at Power 0: the aura swirl and lick field animate every
	# frame, and at rest they are quietest - keeps the diff about the EVENT rather than
	# ambient shader phase drift (the fake-PSNR idle-sway trap).
	dice._on_active_dice_changed("blue")
	_set_power(0, [])
	await _settle(45)

	# ---------- row clearance derived from the real row rect ----------
	var mat := dice.emanation.material as ShaderMaterial
	var row_bottom: float = mat.get_shader_parameter("row_bottom_y")
	var expected := (214.0 + 72.0) - DIE_CENTER.y  # row bottom edge, die-centred
	_check("R1 row clearance synced from the live row rect",
			absf(row_bottom - expected) < 1.5,
			"got=%.1f expected=%.1f" % [row_bottom, expected])

	# ---------- A: non-active charge (magma while blue is active) ----------
	dice_interface.visible = false  # keep delivery flights out of the measured field
	var base_a: Image = await _grab()
	var rest_scale: Vector2 = dice.dice_display.scale
	var max_display_dev := 0.0
	var peak_gust := 0.0
	var radius_min := 999.0
	var radius_max := -999.0
	var prof_early := {}
	var prof_late := {}
	var end_gust := -1.0
	Events.dice_charged.emit("magma", 1)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1100:
		await get_tree().process_frame
		var elapsed := Time.get_ticks_msec() - t0
		var g: float = mat.get_shader_parameter("gust")
		var r: float = mat.get_shader_parameter("gust_radius")
		peak_gust = maxf(peak_gust, g)
		if g > 0.05:
			radius_min = minf(radius_min, r)
			radius_max = maxf(radius_max, r)
		max_display_dev = maxf(max_display_dev,
				(dice.dice_display.scale - rest_scale).length())
		if prof_early.is_empty() and elapsed >= 90:
			prof_early = _radial_profile(await _grab(), base_a)
		elif prof_late.is_empty() and elapsed >= 300:
			prof_late = _radial_profile(await _grab(), base_a)
		end_gust = g
	var early_inner := _band_mean(prof_early, 60, 90)
	var early_outer := _band_mean(prof_early, 120, 160)
	var late_inner := _band_mean(prof_late, 60, 90)
	var late_outer := _band_mean(prof_late, 120, 160)

	_check("A1 gust fired", peak_gust > 0.5, "peak=%.2f" % peak_gust)
	_check("A2 gust settled back to rest", end_gust < 0.01, "end=%.3f" % end_gust)
	_check("A3 front crossed a real distance",
			radius_max - radius_min > 55.0,
			"%.0f -> %.0f px" % [radius_min, radius_max])
	# THE round-1 regression guard: energy must leave the die, not just brighten on it.
	_check("A4 starts concentrated at the die", early_inner > early_outer * 1.5,
			"inner=%.3f outer=%.3f" % [early_inner, early_outer])
	_check("A5 energy departs (outer overtakes inner)", late_outer > late_inner,
			"inner=%.3f outer=%.3f" % [late_inner, late_outer])
	_check("A6 outer band genuinely lights up later",
			late_outer > early_outer * 1.6,
			"early=%.3f late=%.3f" % [early_outer, late_outer])
	_check("A7 no absorb on non-active charge", max_display_dev < 0.001,
			"dev=%.3f" % max_display_dev)

	# ---------- B: active charge, count 3 (pulse + absorb ceremony still gated on) ----------
	dice_interface.visible = true
	_set_power(6, [4, 2])
	await _settle(60)
	var b_max_display := 1.0
	var b_peak_gust := 0.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1200:
		await get_tree().process_frame
		b_max_display = maxf(b_max_display, dice.dice_display.scale.x)
		b_peak_gust = maxf(b_peak_gust, mat.get_shader_parameter("gust"))
		if Time.get_ticks_msec() - t0 < 40:
			Events.dice_charged.emit("blue", 3)
	_check("B1 absorb punch still fires on the active type", b_max_display >= 1.15,
			"max=%.2f" % b_max_display)
	_check("B2 count ladder raises the front", b_peak_gust > peak_gust,
			"c1=%.2f c3=%.2f" % [peak_gust, b_peak_gust])

	# ---------- C: same-frame multi-type volley collapses to one front ----------
	await _settle(50)
	Events.dice_charged.emit("magma", 1)
	await get_tree().process_frame
	var r_after_first: float = mat.get_shader_parameter("gust_radius")
	Events.dice_charged.emit("evil", 1)
	await get_tree().process_frame
	var r_after_second: float = mat.get_shader_parameter("gust_radius")
	_check("C1 volley cooldown does not restart the front",
			r_after_second >= r_after_first,
			"%.1f -> %.1f" % [r_after_first, r_after_second])
	await _settle(50)

	print("[charge-pulse] done: %d checks, %d FAIL -> %s" % [checks, fails, out_dir])
	get_tree().quit(1 if fails > 0 else 0)


func _run_movie_pass() -> void:
	_build_stage(self)
	await get_tree().create_timer(0.8).timeout
	dice._on_active_dice_changed("blue")
	_set_power(6, [4, 2])
	await get_tree().create_timer(0.8).timeout
	print("[charge-pulse-movie] beat A (magma x1) frame ", Engine.get_frames_drawn())
	Events.dice_charged.emit("magma", 1)
	await get_tree().create_timer(1.6).timeout
	print("[charge-pulse-movie] beat B (blue x3) frame ", Engine.get_frames_drawn())
	Events.dice_charged.emit("blue", 3)
	await get_tree().create_timer(1.8).timeout
	get_tree().quit()
