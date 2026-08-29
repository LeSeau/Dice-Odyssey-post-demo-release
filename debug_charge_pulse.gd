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
# Since 2026-08-28 the pulse fires on Events.dice_charge_delivered - the volley's LAST
# delivered die LANDING in its slot - not on dice_charged. So the harness runs two ways:
#   * A/B (physics of the front) keep flights DISABLED. With no node in group "ui_layer"
#     the interface takes its no-flight fallback and announces delivery immediately, which
#     keeps the pulse the only thing moving in the measured field. Flying dice, their mote
#     trails and the launch flare would all land inside the very corridors A4/A5 sample.
#     Do NOT "fix" this by adding a ui_layer to _build_stage - it wrecks A4/A5.
#   * C/D (timing of the trigger) ENABLE flights and exercise the real shipped path.
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
# Mirrors battle.tscn's DiceInterface placement - keep in step with it, the row-clearance
# check below asserts the shader derived its bounds from exactly this rect.
const ROW_POS := Vector2(514, 214)
const ROW_SIZE := Vector2(160, 72)

var vp: SubViewport
var dice: Control
var dice_interface: Control
var ui_layer: Control      # in group "ui_layer" only while flights are enabled - see header
var out_dir := ""
var checks := 0
var fails := 0
var delivered_count := 0   # Events.dice_charge_delivered tally (exactly-once check)


# Group membership is the switch the interface actually reads, so toggling it is how the
# harness chooses between "real delivery flights" and "instant no-flight fallback".
func _set_flights_enabled(enabled: bool) -> void:
	if ui_layer == null:
		return
	if enabled and not ui_layer.is_in_group("ui_layer"):
		ui_layer.add_to_group("ui_layer")
	elif not enabled and ui_layer.is_in_group("ui_layer"):
		ui_layer.remove_from_group("ui_layer")


func _on_delivered(_type: String, _count: int) -> void:
	delivered_count += 1


# get_shader_parameter returns null until a uniform has actually been ASSIGNED once, even
# when the shader declares a default - reading one straight into a typed float throws
# before the run's first pulse (the documented "shader params must be seeded" trap).
func _param_f(mat: ShaderMaterial, param: String) -> float:
	var v = mat.get_shader_parameter(param)
	return 0.0 if v == null else float(v)


# Polls the front every frame for `ms` of REAL time (wall clock, so the volley's hit-stop
# cannot stall the loop) and reports when it first woke up, how many distinct TINTS lit up,
# and how often the radius restarted.
#
# `tints` is the load-bearing one and `resets` is only diagnostic. Counting a backwards jump
# in gust_radius as "a new front" is how this used to work, and it is FLAKY (measured: 1 run
# in 3) now that the detonation carries the volley hit-stop: how far the first front has
# travelled by the time the second fires depends on how much game time the freeze ate, which
# is real-time-dependent and varies per run. gust_color is set once per _fire_gust and each
# volley in a multi-type charge is a different die type, so counting tint changes tests the
# thing the check is actually about - bam-bam in two colours - without depending on timing.
func _watch_front(mat: ShaderMaterial, ms: int) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var first := -1
	var peak := 0.0
	var resets := 0
	var tints := 0
	var prev_r := _param_f(mat, "gust_radius")
	var prev_c: Color = Color(-1, -1, -1)
	while Time.get_ticks_msec() - t0 < ms:
		await get_tree().process_frame
		var g := _param_f(mat, "gust")
		var r := _param_f(mat, "gust_radius")
		peak = maxf(peak, g)
		if first < 0 and g > 0.05:
			first = Time.get_ticks_msec() - t0
		if r < prev_r - 20.0:
			resets += 1
		if g > 0.05:
			var c: Color = mat.get_shader_parameter("gust_color")
			if c != null and (prev_c.r < 0.0 or not c.is_equal_approx(prev_c)):
				tints += 1
				prev_c = c
		prev_r = r
	return {"first_ms": first, "peak": peak, "resets": resets, "tints": tints}


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
	dice_interface.position = ROW_POS - Vector2(0.0, row_dy)
	dice_interface.size = ROW_SIZE
	# battle.tscn puts its instance in this group; a bare instantiate is not in it, and
	# dice.gd reads the group to derive the shader's row-clearance bounds.
	dice_interface.add_to_group("dice_interface")

	# Flight host. Deliberately NOT in group "ui_layer" yet: the A/B measurement blocks need
	# an empty field (see header), and _set_flights_enabled() opts in for C/D.
	ui_layer = Control.new()
	ui_layer.name = "HarnessUILayer"
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.size = Vector2(VIEW)
	parent.add_child(ui_layer)

	dice = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	parent.add_child(dice)
	dice.position = DIE_POS
	dice.size = Vector2(144, 144)
	# Only override when the env var is actually set - int("") is 0, which would silently
	# force the standard variant and hide whatever the shipped default is.
	var mode_env := OS.get_environment("CHARGE_PULSE_MODE")
	if mode_env != "":
		dice.charge_pulse_mode = int(mode_env)


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
	Events.dice_charge_delivered.connect(_on_delivered)

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
	var expected := (ROW_POS.y + ROW_SIZE.y) - DIE_CENTER.y  # row bottom edge, die-centred
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
		# Sample by the front's POSITION, not by wall-clock: variants travel at different
		# speeds, and a fixed "late" timestamp lands after a fast variant has already
		# finished (which reads as "the wave never left" - a false failure).
		if prof_early.is_empty() and r >= 2.0:
			prof_early = _radial_profile(await _grab(), base_a)
		elif prof_late.is_empty() and r >= 55.0:
			prof_late = _radial_profile(await _grab(), base_a)
		end_gust = g
	# An empty profile means the sampling condition never triggered - fail loudly rather
	# than letting _band_mean return 0.0 and quietly satisfy a comparison.
	_check("A0 both sample points captured",
			not prof_early.is_empty() and not prof_late.is_empty(),
			"early=%d late=%d" % [prof_early.size(), prof_late.size()])
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

	# ---------- C: same-frame multi-type volleys each get their OWN front ----------
	# This check used to assert the opposite. Before 2026-08-28 both charges pulsed at CAST
	# time, one frame apart, so the 110ms cooldown swallowed the second and one front was
	# correct. Now the interface sequences volleys (>= CHARGE_STAGGER apart) and the pulse
	# rides each LANDING, so a multi-type charge is MEANT to read as bam-bam in two colors.
	# Counted off gust_color changing, not off the radius restarting - see _watch_front for
	# why the radius signal went flaky once the hit-stop moved onto the detonation.
	_set_flights_enabled(true)
	await _settle(60)
	Events.dice_charged.emit("magma", 1)
	Events.dice_charged.emit("evil", 1)
	var c_watch: Dictionary = await _watch_front(mat, 2600)
	_check("C1 sequenced volleys each fire their own front",
			int(c_watch["tints"]) >= 2,
			"tints=%d radius-resets=%d peak=%.2f" % [int(c_watch["tints"]),
					int(c_watch["resets"]), float(c_watch["peak"])])

	# ---------- D: the trigger itself - does the pulse WAIT for the delivery? ----------
	# D1 is the whole point of the 2026-08-28 retiming. With 3 dice the last one lands at
	# roughly stagger*2 + birth + flight = ~0.95s, so a front that wakes up inside the first
	# ~0.4s means something is still firing at cast time.
	await _settle(90)
	Events.dice_charged.emit("magma", 3)
	var d_watch: Dictionary = await _watch_front(mat, 3000)
	var d_first := int(d_watch["first_ms"])
	_check("D1 pulse waits for the landing, not the cast",
			d_first > 400 and d_first < 3000,
			"first gust at %d ms (peak %.2f)" % [d_first, float(d_watch["peak"])])

	# D2: the arrival callback and the interface's own failsafe timer both race to announce
	# the delivery. The window deliberately outlasts that timer (flight total + 1.0s) so a
	# double-fire - which would double-pulse every charge in the game - shows up here.
	await _settle(90)
	delivered_count = 0
	Events.dice_charged.emit("blue", 2)
	var t_d2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_d2 < 3500:
		await get_tree().process_frame
	_check("D2 exactly one delivery per volley (failsafe never doubles)",
			delivered_count == 1, "emitted=%d" % delivered_count)

	# D3: with no ui_layer nothing can fly, so the payoff moment is immediately - otherwise
	# every harness and boot context would lose the charge pulse entirely.
	_set_flights_enabled(false)
	await _settle(30)
	delivered_count = 0
	Events.dice_charged.emit("magma", 1)
	await _settle(12)
	_check("D3 no-flight fallback still cues the die", delivered_count == 1,
			"emitted=%d" % delivered_count)
	await _settle(40)

	# ---------- E: the wind-up beat (round 3, 2026-08-29) ----------
	# Julien: "it feels rushed... instantly after the charged dice goes to the dice
	# interface we get a very fast pulse. I want dice goes to dice interface, very small
	# anticipation, boom! pulse. And more of a strong shockwave than a fast pulse."
	# So three separate things have to stay true, and each has its own way of silently
	# regressing:
	#   E1 the bang is NOT on the landing frame (delete the delay -> this drops to ~0 ms)
	#   E2 the front and the absorb punch are ONE bang (they were 0.30s apart before, each
	#      driven by its own timing constant - the whole reason it read as two events)
	#   E3 the front HOLDS at peak instead of blinking (drop CHARGE_GUST_HOLD -> the
	#      plateau collapses from ~0.13s to ~0.03s of game time)
	# E3 is measured in GAME seconds, not wall clock: the detonation fires its own
	# hit-stop, and in real time that freeze smears the decay curve enough that a
	# hold-less front still lingers near peak for a couple of hundred ms. Measured against
	# the clock the tween itself runs on, the plateau is unambiguous. (A first version of
	# this check used wall clock and PASSED against the negative control - i.e. it proved
	# nothing at all.)
	# Flights stay disabled so delivery is immediate and t0 IS the landing frame.
	_set_flights_enabled(false)
	dice._on_active_dice_changed("blue")
	_set_power(6, [4, 2])
	await _settle(60)
	var e_rest: Vector2 = dice.dice_display.scale
	var e_gust_ms := -1
	var e_punch_ms := -1
	var e_samples: Array = []
	var e_game_t := 0.0
	Events.dice_charged.emit("blue", 2)
	var e_t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - e_t0 < 1600:
		await get_tree().process_frame
		e_game_t += get_process_delta_time()  # scaled by the hit-stop, i.e. tween time
		var ms := Time.get_ticks_msec() - e_t0
		var g := _param_f(mat, "gust")
		e_samples.append([ms, g, e_game_t])
		if e_gust_ms < 0 and g > 0.05:
			e_gust_ms = ms
		if e_punch_ms < 0 and dice.dice_display.scale.x > e_rest.x * 1.10:
			e_punch_ms = ms
	var e_peak := 0.0
	for sample in e_samples:
		e_peak = maxf(e_peak, float(sample[1]))
	var e_hold_first := -1.0
	var e_hold_last := -1.0
	for sample in e_samples:
		# 0.995 and not 0.9: a QUAD ease-in decay leaves the value within 10% of peak for
		# ~0.14s all by itself, so a loose threshold cannot tell a plateau from a curve.
		if float(sample[1]) >= e_peak * 0.995:
			if e_hold_first < 0.0:
				e_hold_first = float(sample[2])
			e_hold_last = float(sample[2])
	var e_hold_span := (e_hold_last - e_hold_first) if e_hold_first >= 0.0 else 0.0
	# Wall-clock, and the window is generous on the late side on purpose: the detonation
	# fires its own hit-stop, so everything after it is stretched by the freeze.
	_check("E1 the bang waits out a wind-up beat after the landing",
			e_gust_ms > 120 and e_gust_ms < 450, "gust at %d ms" % e_gust_ms)
	_check("E2 front and absorb punch are one bang",
			e_punch_ms >= 0 and absf(float(e_punch_ms - e_gust_ms)) < 160.0,
			"gust=%d ms punch=%d ms" % [e_gust_ms, e_punch_ms])
	_check("E3 the front holds at peak instead of blinking",
			e_hold_span >= 0.07,
			"peak=%.2f plateau %.0f ms of game time" % [e_peak, e_hold_span * 1000.0])

	print("[charge-pulse] done: %d checks, %d FAIL -> %s" % [checks, fails, out_dir])
	get_tree().quit(1 if fails > 0 else 0)


func _run_movie_pass() -> void:
	_build_stage(self)
	# The strip exists to show the NEW phrase - launch flare, flight, rising plinks, then
	# clack + kick + freeze + gust on one beat - so the visual pass needs real flights and
	# beats long enough to contain a whole delivery (~1s) plus its pulse.
	_set_flights_enabled(true)
	await get_tree().create_timer(0.8).timeout
	dice._on_active_dice_changed("blue")
	_set_power(6, [4, 2])
	await get_tree().create_timer(0.8).timeout
	print("[charge-pulse-movie] beat A (magma x1) frame ", Engine.get_frames_drawn())
	Events.dice_charged.emit("magma", 1)
	await get_tree().create_timer(2.8).timeout
	print("[charge-pulse-movie] beat B (blue x3) frame ", Engine.get_frames_drawn())
	Events.dice_charged.emit("blue", 3)
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
