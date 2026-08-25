extends Node

# Measurement + render harness for the contained charge pulse (2026-08-25).
# Boots the die cluster over the act-1 background (same recipe as debug_dice_glow),
# emits REAL Events.dice_charged signals and verifies the new wavefront:
#   A  non-active charge  -> ring spawns, contained travel, readable speed, ZERO
#                            dice_display.scale motion (the absorb stays gated), cleanup.
#   A0 negative control   -> ring suppressed (cooldown forced) so the lit-pixel metric
#                            proves it is measuring the RING, not the aura flare.
#   B  active charge x3   -> main front + echo, absorb punch still fires, cleanup.
#   C  same-frame volley  -> cooldown collapses two emits into one front set.
# Also saves a frame strip of A and B for eyeballing.
#
# Run:
#   Godot_v4.3-stable_win64_console.exe --path . res://debug_charge_pulse.tscn
#       --rendering-driver opengl3 --position 2000,2000
# Env: CHARGE_PULSE_OUT = absolute output dir (falls back to user://charge_pulse)

const VIEW := Vector2i(1280, 720)
const DIE_CENTER := Vector2(598, 371)  # dice at (521,294) + panel center (77,77)

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


func _rings() -> Array:
	return get_tree().get_nodes_in_group("charge_pulse_ring")


# Lit-pixel area (in real px, stride-2 sampled) of |frame - baseline| in the bottom half
# around the die - below die center so neither delivery flights (they fly UP) nor the
# power label pollute the count. The ROLL button is opaque and occludes the ring there,
# which subtracts itself out of the diff naturally.
func _lit_area(img: Image, base: Image) -> int:
	var count := 0
	for y in range(371, 571, 2):
		for x in range(438, 758, 2):
			var c := img.get_pixel(x, y)
			var b := base.get_pixel(x, y)
			var d := absf(c.r - b.r) + absf(c.g - b.g) + absf(c.b - b.b)
			if d > 0.12:
				count += 1
	return count * 4


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _ready() -> void:
	Global.tutorial_on = true  # mute achievements while the harness fakes game events
	out_dir = OS.get_environment("CHARGE_PULSE_OUT")
	if out_dir == "":
		out_dir = "user://charge_pulse"
	DirAccess.make_dir_recursive_absolute(out_dir)

	# CHARGE_PULSE_MOVIE=1: visual-only pass for Movie Maker capture (fixed-dt frames -
	# realtime PNG saving compresses tween motion, the documented capture trap). Builds the
	# stage on the real window instead of the offscreen SubViewport, spaces beats with
	# GAME-time timers, and runs no checks (assert truth = the run without --write-movie).
	# Run with: --write-movie <dir>/f.png --fixed-fps 30 --resolution 1280x720
	if OS.get_environment("CHARGE_PULSE_MOVIE") != "":
		await _run_movie_pass()
		return

	Global.blue_dice_max_amount = 2
	Global.blue_dice_current_amount = 2
	Global.red_dice_max_amount = 1
	Global.red_dice_current_amount = 1
	Global.magma_dice_max_amount = 1
	Global.magma_dice_current_amount = 1
	Global.evil_dice_max_amount = 1
	Global.evil_dice_current_amount = 1

	vp = SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/combat_bg_act1_hallway_mountain_ruins.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(VIEW)
	bg.modulate = Color(0.74, 0.74, 0.74)
	vp.add_child(bg)

	dice_interface = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	vp.add_child(dice_interface)
	dice_interface.position = Vector2(514, 214)
	dice_interface.size = Vector2(160, 72)

	dice = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	vp.add_child(dice)
	dice.position = Vector2(521, 294)
	dice.size = Vector2(144, 144)

	await _settle(30)
	# Measurement scenarios run at Power 0: the aura swirl + emanation tongues animate
	# every frame, and at rest they are minimal - keeps the pixel diff about the RING,
	# not about ambient shader phase drift (the fake-PSNR idle-sway trap).
	dice._on_active_dice_changed("blue")
	Global.roll_value = 0
	Global.roll_history = []
	dice.update_roll_history_ui()
	dice._set_power_text(0)
	dice._update_dice_aura_charge()
	await _settle(45)

	# ---------- A0: negative control (ring suppressed via forced cooldown) ----------
	dice_interface.visible = false  # keep delivery flights out of the visual field
	var base_a0: Image = await _grab()
	dice._last_charge_pulse_ms = Time.get_ticks_msec()  # forces the cooldown early-return
	Events.dice_charged.emit("magma", 1)
	var control_early := -1
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 500:
		await get_tree().process_frame
		if control_early < 0 and Time.get_ticks_msec() - t0 >= 60:
			var img: Image = await _grab()
			control_early = _lit_area(img, base_a0)
	_check("A0 control spawned no ring", _rings().is_empty())
	await _settle(60)  # let the aura flare fully settle before the real run

	# ---------- A: non-active charge (magma while blue is active) ----------
	var base_a: Image = await _grab()
	var rest_scale: Vector2 = dice.dice_display.scale
	Events.dice_charged.emit("magma", 1)
	var ring_seen := false
	var first_radius := -1.0
	var max_radius := -1.0
	var max_display_dev := 0.0
	var lit_early := -1
	var lit_mid := -1
	var lit_late := -1
	var last_alive_ms := 0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1300:
		await get_tree().process_frame
		var elapsed := Time.get_ticks_msec() - t0
		var rings := _rings()
		for r in rings:
			ring_seen = true
			last_alive_ms = elapsed
			var radius: float = r.scale.x * r.texture.get_width() * 0.5 \
					* DicePalette.DIE_RING_BAND_FRACTION
			if first_radius < 0.0:
				first_radius = radius
			max_radius = maxf(max_radius, radius)
		max_display_dev = maxf(max_display_dev,
				(dice.dice_display.scale - rest_scale).length())
		if lit_early < 0 and elapsed >= 60:
			lit_early = _lit_area(await _grab(), base_a)
		elif lit_mid < 0 and elapsed >= 210:
			lit_mid = _lit_area(await _grab(), base_a)
		elif lit_late < 0 and elapsed >= 380:
			lit_late = _lit_area(await _grab(), base_a)
	_check("A1 ring spawned", ring_seen)
	_check("A2 spawn radius just past panel edge", first_radius >= 78.0 and first_radius <= 95.0,
			"first=%.1f" % first_radius)
	_check("A3 contained travel", max_radius > 100.0 and max_radius <= 135.0,
			"max=%.1f" % max_radius)
	_check("A4 readable lifetime", last_alive_ms >= 330 and last_alive_ms <= 650,
			"alive=%dms" % last_alive_ms)
	_check("A5 no absorb on non-active charge", max_display_dev < 0.001,
			"dev=%.3f" % max_display_dev)
	_check("A6 ring visibly lights the field vs control",
			lit_early > 2000 and lit_early > control_early * 2,
			"early=%d control=%d" % [lit_early, control_early])
	_check("A7 front decays over travel", lit_late < lit_early,
			"early=%d mid=%d late=%d" % [lit_early, lit_mid, lit_late])
	_check("A8 not a wash", lit_early < 70000, "early=%d" % lit_early)
	_check("A9 rings cleaned up", _rings().is_empty())

	# ---------- B: active charge, count 3 (universal pulse + absorb ceremony) ----------
	dice_interface.visible = true
	Global.roll_value = 6
	Global.roll_history = [4, 2]
	dice.update_roll_history_ui()
	dice._set_power_text(6)
	dice._update_dice_aura_charge()
	await _settle(60)
	Events.dice_charged.emit("blue", 3)
	var b_ring_max := 0
	var b_max_display := 1.0
	var frame_idx := 0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1300:
		await get_tree().process_frame
		b_ring_max = maxi(b_ring_max, _rings().size())
		b_max_display = maxf(b_max_display, dice.dice_display.scale.x)
		if frame_idx % 2 == 0 and frame_idx < 56:
			var img: Image = await _grab()
			img.save_png(out_dir.path_join("b_active_f%03d.png" % frame_idx))
		frame_idx += 1
	_check("B1 main front + echo on count 3", b_ring_max == 2, "max=%d" % b_ring_max)
	_check("B2 absorb punch still fires", b_max_display >= 1.15, "max=%.2f" % b_max_display)
	_check("B3 rings cleaned up", _rings().is_empty())

	# ---------- C: same-frame multi-type volley collapses to one front set ----------
	await _settle(30)
	Events.dice_charged.emit("magma", 1)
	Events.dice_charged.emit("evil", 1)
	await get_tree().process_frame
	_check("C1 volley cooldown holds one front", _rings().size() == 1,
			"rings=%d" % _rings().size())
	await _settle(50)

	# ---------- Visual strip of scenario A (interface visible, real composite) ----------
	await _settle(40)
	Events.dice_charged.emit("magma", 1)
	for f in 30:
		var img: Image = await _grab()
		img.save_png(out_dir.path_join("a_universal_f%03d.png" % f))
		await get_tree().process_frame

	print("[charge-pulse] done: %d checks, %d FAIL -> %s" % [checks, fails, out_dir])
	get_tree().quit(1 if fails > 0 else 0)


func _run_movie_pass() -> void:
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
	add_child(bg)

	dice_interface = (load("res://scenes/dices/dice_interface.tscn") as PackedScene).instantiate()
	add_child(dice_interface)
	dice_interface.position = Vector2(514, 214)
	dice_interface.size = Vector2(160, 72)

	dice = (load("res://scenes/dices/dice.tscn") as PackedScene).instantiate()
	add_child(dice)
	dice.position = Vector2(521, 294)
	dice.size = Vector2(144, 144)

	await get_tree().create_timer(0.8).timeout
	dice._on_active_dice_changed("blue")
	Global.roll_value = 6
	Global.roll_history = [4, 2]
	dice.update_roll_history_ui()
	dice._set_power_text(6)
	dice._update_dice_aura_charge()
	await get_tree().create_timer(0.8).timeout
	print("[charge-pulse-movie] beat A (magma x1) at engine frame ", Engine.get_frames_drawn())
	Events.dice_charged.emit("magma", 1)
	await get_tree().create_timer(1.6).timeout
	print("[charge-pulse-movie] beat B (blue x3) at engine frame ", Engine.get_frames_drawn())
	Events.dice_charged.emit("blue", 3)
	await get_tree().create_timer(1.8).timeout
	get_tree().quit()
