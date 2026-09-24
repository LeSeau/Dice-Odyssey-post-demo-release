extends RefCounted

# ============================================================================
# ENEMY ATTACK MOTION (2026-09-23)
#
# Every attack used to be one of 64 copies of the same tween: a 0.4s TRANS_QUINT glide with
# Godot's default EASE_IN_OUT, so the enemy was nearly STOPPED at the instant it touched the
# hero. The hit landed on the slowest frame of the whole move, and a 3-damage Satyr poke moved
# exactly like a 24-damage Ink Tide. Impact reads when the attacker is at FULL speed on contact
# and the hit-stop then freezes it there.
#
# Two motions behind one contract (EnemyAction.run_attack):
#   LUNGE - pull back and lean away (longer and deeper for bigger hits), then a dash that
#           ACCELERATES into contact, a squash against the hero, a recoil and the return.
#           Multi-hits jab again before every later blow instead of landing it standing still.
#   CAST  - casters stop running across the screen to melee. They rise and glow while a bolt
#           gathers in front of them, throw it, and the damage lands when the bolt arrives.
# Timing stays close to the old ~1s per attack, so enemy turns do not get longer.
#
# No class_name on purpose: EnemyAction preloads this file, and a fresh class_name is invisible
# to headless harnesses until the editor rescans (see CLAUDE.md, headless class cache).
# `enemy` is deliberately UNTYPED everywhere below: typing it `Enemy` would make this file depend
# on enemy.gd, which depends on EnemyAction, which preloads this file - a parse-time cycle. So
# every value read off it is given an explicit type (`:=` on an untyped read does not compile).
#
# Every per-tier table is indexed by the Shaker.Impact rung of the per-hit damage
# (VERY_WEAK 0 .. HUGE 4). Reads are typed on purpose: indexing a const Array yields Variant.
# ============================================================================

# --- LUNGE ---
const LUNGE_WINDUP: Array[float] = [0.12, 0.14, 0.18, 0.24, 0.32]
const LUNGE_PULL: Array[float] = [10.0, 16.0, 24.0, 34.0, 46.0]
const LUNGE_LEAN_BACK: Array[float] = [0.03, 0.05, 0.07, 0.09, 0.12]  # radians, + = away from the hero
const LUNGE_TREMBLE: Array[float] = [0.0, 0.0, 0.0, 2.0, 3.0]        # px, heavy hits shake as they coil
const LUNGE_DASH: Array[float] = [0.15, 0.16, 0.17, 0.18, 0.2]
const LUNGE_CROUCH := Vector2(1.07, 0.92)
const LUNGE_STRETCH := Vector2(1.12, 0.94)
const LUNGE_LEAN_FORWARD := -0.07
# Set instantly on contact (not tweened), so the compression lands on the exact frame the
# hit-stop freezes.
const LUNGE_IMPACT_SQUASH := Vector2(0.9, 1.06)
const LUNGE_RECOIL := 18.0
const LUNGE_RECOIL_TIME := 0.1
const LUNGE_POSE_RECOVER := 0.18
const LUNGE_RETURN := 0.34
const LUNGE_JAB := 22.0
# Where the enemy ROOT stops, relative to the hero - unchanged from the old tween, so every
# enemy still lands exactly where it always has.
const CONTACT_OFFSET := Vector2(32.0, 0.0)

# --- CAST ---
const CAST_CHARGE: Array[float] = [0.22, 0.26, 0.3, 0.36, 0.44]
const CAST_RISE: Array[float] = [10.0, 14.0, 18.0, 24.0, 30.0]
# Screen px. The glow texture falls off fast, so only ~40% of this reads as bright: the first
# pass (36-72) rendered as a ~20px spark that read as a stray pixel, not a spell.
const CAST_ORB_SIZE: Array[float] = [58.0, 68.0, 80.0, 96.0, 116.0]
const CAST_LEAN_BACK := 0.05
const CAST_THROW_LEAN := -0.06
const CAST_BOLT_TIME := 0.26
# Added to every pixel of the caster for the whole cast - 0.5 washed the Lich flat lilac.
const CAST_FLASH := 0.18
const CAST_RECOVER := 0.34
const BOLT_Z := 30
const BOLT_MOTE_INTERVAL_MS := 11
const BOLT_MOTE_LIFETIME := 0.26
const IMPACT_FLARE_TIME := 0.22
const IMPACT_RING_TIME := 0.3


static func tier_for(power: int) -> int:
    return clampi(int(Shaker.impact_for_damage(power)), 0, 4)


# steps -> beats. A Callable joins the current beat; a number is the gap before the NEXT beat.
# Returns [{"calls": Array, "gap": float}], gap = seconds between this beat and the previous one.
static func group_beats(steps: Array) -> Array:
    var beats: Array = []
    var pending_gap := 0.0
    for step in steps:
        if step is Callable:
            if beats.is_empty() or pending_gap > 0.0:
                beats.append({"calls": [step], "gap": pending_gap})
                pending_gap = 0.0
            else:
                (beats[beats.size() - 1]["calls"] as Array).append(step)
        elif step is float or step is int:
            pending_gap += float(step)
    return beats


# A Callable does NOT keep its RefCounted target alive (measured 2026-09-23), so an attack's
# DamageEffect would be freed the moment perform_action() returns and the hit would silently
# never land. The old per-script tweens only survived because Tween.tween_callback() takes a
# hidden reference. These strong references are bound into the final callback instead, so they
# live exactly as long as the motion does.
static func anchors_for(steps: Array) -> Array:
    var out: Array = []
    for step in steps:
        if step is Callable:
            var obj: Object = (step as Callable).get_object()
            if obj != null and obj is RefCounted:
                out.append(obj)
    return out


static func lunge(enemy, target: Node2D, steps: Array, hold: float, power: int) -> void:
    var beats := group_beats(steps)
    var anchors := anchors_for(steps)
    var tier := tier_for(power)
    var start: Vector2 = enemy.global_position
    var contact := target.global_position + CONTACT_OFFSET
    var away := (start - contact).normalized()
    if away.is_zero_approx():
        away = Vector2.RIGHT
    var windup: float = LUNGE_WINDUP[tier]
    var pull: float = LUNGE_PULL[tier]
    var lean_back: float = LUNGE_LEAN_BACK[tier]
    var tremble: float = LUNGE_TREMBLE[tier]
    var dash: float = LUNGE_DASH[tier]

    enemy.begin_attack_motion()
    var tw: Tween = enemy.create_tween()

    # 1. Wind-up: back off, lean away, crouch. Decelerating, so the coil reads as held tension.
    tw.tween_property(enemy, "global_position", start + away * pull, windup) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(enemy, "pose_lean", lean_back, windup) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(enemy, "pose_scale", LUNGE_CROUCH, windup) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    if tremble > 0.0:
        tw.parallel().tween_method(enemy.set_pose_tremble.bind(tremble), 0.0, 1.0, windup)

    # 2. Dash: ACCELERATING, so contact is the fastest frame of the move.
    tw.tween_property(enemy, "global_position", contact, dash) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(enemy, "pose_lean", LUNGE_LEAN_FORWARD, dash) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(enemy, "pose_scale", LUNGE_STRETCH, dash) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(enemy, "pose_shift", Vector2.ZERO, minf(dash, 0.05))

    # 3. Contacts. Later blows of a multi-hit jab back and drive in again inside the same gap the
    # old tween waited, so the rhythm between hits is unchanged.
    for i in beats.size():
        var beat: Dictionary = beats[i]
        var gap: float = beat["gap"]
        if i > 0 and gap > 0.0:
            var back := gap * 0.5
            tw.tween_property(enemy, "global_position", contact + away * LUNGE_JAB, back) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            tw.parallel().tween_property(enemy, "pose_lean", lean_back * 0.6, back) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            tw.parallel().tween_property(enemy, "pose_scale", LUNGE_CROUCH, back) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            tw.tween_property(enemy, "global_position", contact, gap - back) \
                .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
            tw.parallel().tween_property(enemy, "pose_lean", LUNGE_LEAN_FORWARD, gap - back) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
            tw.parallel().tween_property(enemy, "pose_scale", LUNGE_STRETCH, gap - back) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tw.tween_callback(contact_beat.bind(enemy, beat["calls"], true))

    # 4. Recoil off the hero, hold (the old tween's interval before the return), come home.
    tw.tween_property(enemy, "global_position", contact + away * LUNGE_RECOIL, LUNGE_RECOIL_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(enemy, "pose_scale", Vector2.ONE, LUNGE_POSE_RECOVER) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(enemy, "pose_lean", 0.0, LUNGE_POSE_RECOVER) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    var rest_hold := maxf(hold - LUNGE_POSE_RECOVER, 0.0)
    if rest_hold > 0.0:
        tw.tween_interval(rest_hold)
    tw.tween_property(enemy, "global_position", start, LUNGE_RETURN) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tw.tween_callback(finish.bind(enemy, anchors))


static func cast(enemy, target: Node2D, steps: Array, hold: float, power: int, color: Color) -> void:
    var beats := group_beats(steps)
    var anchors := anchors_for(steps)
    var tier := tier_for(power)
    var start: Vector2 = enemy.global_position
    var charge: float = CAST_CHARGE[tier]
    var rise: float = CAST_RISE[tier]
    var orb_size: float = CAST_ORB_SIZE[tier]

    enemy.begin_attack_motion()
    enemy.body_flash_color = color
    var orb := _spawn_charge_orb(enemy, color, orb_size, charge)

    var tw: Tween = enemy.create_tween()
    # Charge: rise, lean back, light up while the orb gathers.
    tw.tween_property(enemy, "global_position", start + Vector2(0.0, -rise), charge) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(enemy, "pose_lean", CAST_LEAN_BACK, charge) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(enemy, "body_flash", CAST_FLASH, charge) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

    for i in beats.size():
        var beat: Dictionary = beats[i]
        var bolt_time := CAST_BOLT_TIME
        if i > 0:
            var gap: float = beat["gap"]
            bolt_time = minf(CAST_BOLT_TIME, gap * 0.85)
            var wait := maxf(gap - bolt_time, 0.0)
            if wait > 0.0:
                tw.tween_interval(wait)
        # Only the first bolt grows out of the charge orb; later ones spark straight off the body.
        var from_orb: Node2D = orb if i == 0 else null
        tw.tween_callback(_throw_bolt.bind(enemy, target, color, orb_size, bolt_time, from_orb))
        # The throw: a lean INTO the bolt, then back. Together these last exactly bolt_time, so
        # the contact callback below fires on the frame the bolt arrives.
        tw.tween_property(enemy, "pose_lean", CAST_THROW_LEAN, bolt_time * 0.35) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw.tween_property(enemy, "pose_lean", CAST_LEAN_BACK * 0.5, bolt_time * 0.65) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        tw.tween_callback(_bolt_impact.bind(enemy, target, color, orb_size))
        tw.tween_callback(contact_beat.bind(enemy, beat["calls"], false))

    if hold > 0.0:
        tw.tween_interval(hold)
    tw.tween_property(enemy, "global_position", start, CAST_RECOVER) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tw.parallel().tween_property(enemy, "pose_lean", 0.0, CAST_RECOVER) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(enemy, "body_flash", 0.0, CAST_RECOVER) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_callback(finish.bind(enemy, anchors))


# One contact: whatever the old tween ran at that moment (damage, a status, a junk plant...).
static func contact_beat(enemy, calls: Array, squash: bool) -> void:
    if not is_instance_valid(enemy):
        return
    if squash:
        enemy.pose_scale = LUNGE_IMPACT_SQUASH
    # Thorned Plate reads the attacker off Global.acting_enemy when damage resolves, which is
    # HERE. Enemy.do_turn() sets it around perform_action() and clears it synchronously, long
    # before this contact, so without this the relic never knew who hit you.
    var previous: Node = Global.acting_enemy
    Global.acting_enemy = enemy
    for call in calls:
        var callable: Callable = call
        if callable.is_valid():
            callable.call()
    Global.acting_enemy = previous


static func finish(enemy, _anchors: Array) -> void:
    if not is_instance_valid(enemy):
        return
    enemy.end_attack_motion()
    # A body that died mid-swing (a thorns reflect at contact) was already dropped from the turn
    # queue by EnemyHandler._on_enemy_died, which started the next enemy. Completing it again
    # here would advance the queue twice and give the next enemy a double turn.
    if enemy.is_in_group("enemies"):
        Events.enemy_action_completed.emit(enemy)


# --- Cast visuals -----------------------------------------------------------------------------

static func _make_glow(color: Color, size_px: float) -> Node2D:
    var holder := Node2D.new()
    var glow := Sprite2D.new()
    glow.texture = DicePalette.glow_texture()
    glow.material = DicePalette.additive_material()
    glow.modulate = Color(color.r, color.g, color.b, 1.0)
    glow.scale = Vector2.ONE * (size_px / 256.0)
    holder.add_child(glow)
    # A small white-hot core, so the orb reads as light rather than a coloured disc.
    var core := Sprite2D.new()
    core.texture = DicePalette.glow_texture()
    core.material = DicePalette.additive_material()
    core.modulate = Color(1.0, 0.97, 0.9, 0.9)
    core.scale = Vector2.ONE * (size_px * 0.42 / 256.0)
    holder.add_child(core)
    return holder


static func _spawn_charge_orb(enemy, color: Color, size_px: float, charge: float) -> Node2D:
    var orb := _make_glow(color, size_px)
    # Child of the enemy root so it rides the rise; divided by the per-fight root scale so every
    # caster's orb has the same on-screen size.
    var root_scale: float = maxf(absf(float(enemy.scale.x)), 0.01)
    orb.z_index = 12
    enemy.add_child(orb)
    orb.position = enemy.cast_point_local()
    orb.scale = Vector2.ZERO
    var t := orb.create_tween()
    t.tween_property(orb, "scale", Vector2.ONE / root_scale, charge) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    return orb


static func _target_point(target: Node2D) -> Vector2:
    var sprite = target.get("sprite_2d")
    if sprite is Node2D and is_instance_valid(sprite):
        return (sprite as Node2D).global_position
    return target.global_position + Vector2(0.0, -50.0)


static func _throw_bolt(enemy, target: Node2D, color: Color, size_px: float,
        bolt_time: float, from_orb: Node2D) -> void:
    if not is_instance_valid(enemy) or not is_instance_valid(target):
        return
    var world: Node = enemy.get_parent()
    if world == null:
        return
    var from: Vector2 = enemy.to_global(enemy.cast_point_local())
    if from_orb != null and is_instance_valid(from_orb):
        from = from_orb.global_position
        from_orb.queue_free()
    var bolt := _make_glow(color, size_px)
    bolt.z_index = BOLT_Z
    world.add_child(bolt)
    bolt.global_position = from
    var to := _target_point(target)
    var bt := bolt.create_tween()
    bt.tween_property(bolt, "global_position", to, bolt_time) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    bt.parallel().tween_method(_bolt_trail_step.bind(bolt, world, color, size_px), 0.0, 1.0, bolt_time)
    bt.tween_callback(bolt.queue_free)


# Throttled on the REAL clock: the bolt accelerates, so a t-based interval would clump motes at
# the slow start and leave the fast end bare (same reasoning as card_ui's comet trail).
static var _last_bolt_mote_ms := 0

static func _bolt_trail_step(_t: float, bolt: Node2D, world: Node, color: Color, size_px: float) -> void:
    if not is_instance_valid(bolt) or not is_instance_valid(world):
        return
    var now := Time.get_ticks_msec()
    if now - _last_bolt_mote_ms < BOLT_MOTE_INTERVAL_MS:
        return
    _last_bolt_mote_ms = now
    var mote := Sprite2D.new()
    mote.texture = DicePalette.glow_texture()
    mote.material = DicePalette.additive_material()
    mote.modulate = Color(color.r, color.g, color.b, 0.8)
    mote.z_index = BOLT_Z - 1
    var s := size_px * randf_range(0.45, 0.7) / 256.0
    mote.scale = Vector2(s, s)
    world.add_child(mote)
    mote.global_position = bolt.global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
    var mt := mote.create_tween()
    mt.tween_property(mote, "modulate:a", 0.0, BOLT_MOTE_LIFETIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    mt.parallel().tween_property(mote, "scale", Vector2(s, s) * 0.3, BOLT_MOTE_LIFETIME)
    mt.tween_callback(mote.queue_free)


static func _bolt_impact(enemy, target: Node2D, color: Color, size_px: float) -> void:
    if not is_instance_valid(target) or not is_instance_valid(enemy):
        return
    var world: Node = enemy.get_parent()
    if world == null:
        return
    var at := _target_point(target)
    # Flash: alpha on its own short tween while the scale keeps growing on another - a held
    # additive peak reads as a wash (measured once at 1.63s of saturated white).
    var flare := _make_glow(color, size_px * 1.6)
    flare.z_index = BOLT_Z
    world.add_child(flare)
    flare.global_position = at
    flare.scale = Vector2(0.6, 0.6)
    var ft := flare.create_tween()
    ft.tween_property(flare, "scale", Vector2(1.5, 1.5), IMPACT_FLARE_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    var fa := flare.create_tween()
    fa.tween_property(flare, "modulate:a", 0.0, IMPACT_FLARE_TIME * 0.7) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    fa.tween_callback(flare.queue_free)
    var ring := Sprite2D.new()
    ring.texture = DicePalette.ring_texture()
    ring.material = DicePalette.additive_material()
    ring.modulate = Color(color.r, color.g, color.b, 0.9)
    ring.z_index = BOLT_Z
    world.add_child(ring)
    ring.global_position = at
    var r0 := size_px * 1.2 / 256.0
    ring.scale = Vector2(r0, r0)
    var rt := ring.create_tween()
    rt.tween_property(ring, "scale", Vector2(r0, r0) * 2.6, IMPACT_RING_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    rt.parallel().tween_property(ring, "modulate:a", 0.0, IMPACT_RING_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    rt.tween_callback(ring.queue_free)
