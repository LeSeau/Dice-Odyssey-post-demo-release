extends CPUParticles2D

# Soft radial glow (same visual language as the dice -> Power orbs, see dice.gd's
# _get_power_orb_texture()) + additive blend, so a card's hit reads as the SAME magic that
# powers the dice, unleashed on the enemy - rather than flat colored squares (this node had no
# texture/material set at all before this pass, so it fell back to CPUParticles2D's default
# 1x1 point, drawn as hard-edged squares). Cached statically since every card play spawns and
# frees a fresh instance of this scene - no point rebuilding the same tiny gradient each time.
static var _particle_texture: GradientTexture2D
static var _particle_material: CanvasItemMaterial

static func _get_particle_texture() -> GradientTexture2D:
    if _particle_texture:
        return _particle_texture
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    var tex := GradientTexture2D.new()
    tex.gradient = gradient
    tex.width = 32
    tex.height = 32
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    _particle_texture = tex
    return _particle_texture

static func _get_particle_material() -> CanvasItemMaterial:
    if _particle_material:
        return _particle_material
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _particle_material = mat
    return _particle_material


func play_effect(roll_value: int, dice_type: String) -> void:
    texture = _get_particle_texture()
    material = _get_particle_material()
    var roll_f := float(roll_value)

    # Overbright (same trick as the power orbs' POWER_ORB_BRIGHTNESS), but toned down from an
    # earlier 1.6/alpha-1.0 pass - at typical particle counts below, dozens of overlapping
    # additive-blended glows stack their brightness (unlike the old flat-square particles,
    # where overlap just meant more solid-color coverage, not brightness ADDING UP) - full
    # overbright + full alpha blew out into one solid white sphere instead of individual sparks.
    color = DicePalette.accent(dice_type) * 1.25
    color.a = 0.8

    # --- Quantity & size: base range sized against the new glow texture (10-30px diameter,
    # same ballpark as the dice->Power orbs) so a burst reads as individual sparks rather than
    # fusing into one shape - see the "too big" fix from the previous pass. A small quadratic
    # term is layered on top of the linear base so a turn's worth of STACKED power visibly
    # escalates ("unleashing power stacked from your rolls" per Julien) rather than growing at
    # a flat rate - a 2-power tap stays close to the old modest baseline, but a big banked hit
    # (20-30+ power) noticeably outgrows what plain linear scaling would give it. Clamped so an
    # extreme turn doesn't blow the particle budget or the individual sparks' own size.
    amount = clampi(int(40.0 + 6.0 * roll_f + 0.16 * roll_f * roll_f), 40, 480)
    scale_amount_min = clampf(0.35 + roll_f * 0.008 + roll_f * roll_f * 0.0006, 0.35, 1.3)
    scale_amount_max = clampf(0.6 + roll_f * 0.014 + roll_f * roll_f * 0.001, 0.6, 2.2)

    # --- Velocity & spread: was a tight 42-degree cone (reads as "shoot straight up"), now a
    # real burst - still biased upward via `direction`, but wide enough to genuinely explode
    # outward from the impact point instead of jetting in one direction. Velocity gets a much
    # gentler escalation than count/size above - overdriving speed risks particles flying past
    # the enemy sprite entirely and reading as chaotic rather than impactful.
    initial_velocity_min = 180.0
    initial_velocity_max = clampf(260.0 + roll_f * 16.0 + roll_f * roll_f * 0.4, 260.0, 850.0)
    spread = 165.0
    damping_min = 260.0
    damping_max = 380.0

    # --- Swirl: the "magic" motion the old flat up-and-fade was missing. orbit_velocity spins
    # each particle's path around the emission point (sign randomized per-particle since
    # min < 0 < max, so some curl one way and some the other), tangential_accel adds extra
    # curve to the paths, and a gentle NEGATIVE radial_accel pulls the burst back inward after
    # it expands - reads as "these particles get reclaimed," the same magic-flowing-back
    # language as the dice orbs being absorbed into the Power number.
    orbit_velocity_min = -0.9
    orbit_velocity_max = 0.9
    tangential_accel_min = -150.0
    tangential_accel_max = 150.0
    radial_accel_min = -70.0
    radial_accel_max = -20.0

    # --- Gravity: lighter than before - the swirl above now does most of the "keeps moving"
    # work; heavy gravity would just drag everything straight down through the spiral.
    gravity = Vector2(0, 180)

    # --- Lifetime: extended a touch so the swirl actually has time to read before the burst
    # fades (was tuned only for the old ballistic up-then-fall motion).
    lifetime = 0.42 + float(roll_value) * 0.02

    # --- Hue variation: slight shift for energy feel ---
    hue_variation_min = -0.05
    hue_variation_max = 0.05

    # --- Color ramp: fade to transparent ---
    var gradient := Gradient.new()
    gradient.add_point(0.0, color)
    gradient.add_point(0.55, Color(color.r, color.g, color.b, color.a * 0.6))
    gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
    color_ramp = gradient

    # Defensive one-frame wait so the texture/material assignment above has a chance to reach
    # the renderer before particles start emitting (CPUParticles2D can in principle fall back
    # to flat colored squares - its pre-texture default look - if a freshly-created texture
    # hasn't finished uploading the same frame `emitting` flips true). Kept cheap insurance,
    # but NOT the fix for the square Julien reported - frame-by-frame video analysis showed
    # that artifact persisting for ~150ms, far too long for a one-frame race; it was actually
    # the flash+ring impact-burst Sprite2Ds (removed, see git history / project memory) not
    # rendering their radial gradient correctly. One frame (~16ms) is imperceptible either way.
    await get_tree().process_frame

    emitting = true
    await get_tree().create_timer(lifetime + 0.1).timeout
    queue_free()
