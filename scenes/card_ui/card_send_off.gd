extends Node

# The played card's send-off (2026-09-24): press, glide to the stage, hold while the effect
# lands, then leave by one of three routes - swoosh into the discard pile, burn away (exhaust),
# or swirl into the hero (a Blessing). Shared by the card played from the hand (CardUI) and by
# the Red socket's display (dice.gd), so the two can no longer drift apart. The socket's used to
# be a separate lift-and-arc with no stage, no trail, no flash and no catch.
#
# It is a CHILD of the card it flies, so every tween it owns dies with that card. The only things
# that outlive the card are the pile's arrival bookkeeping (CardPileOpener) and the ribbon, which
# frees itself once its last point has faded.
#
# No class_name: card_ui.gd and dice.gd preload it. It never names CardUI, so there is no preload
# cycle through the class cache.

enum Route { DISCARD, BURN, BLESSING }
enum Phase { INTRO, EXIT, ABSORB, DONE }

const RIBBON_SCRIPT := preload("res://scenes/card_ui/card_ribbon_trail.gd")
const BURN_SHADER := preload("res://scenes/card_ui/card_burn.gdshader")
const FIZZLE_SFX := preload("res://sounds/error.wav")
# Runtime load(), like dice.gd's riser pool: a preload of a file whose .import is missing is a
# parse error, and it would take every card flight down with it. Cached on first use.
const WHOOSH_PATHS: Array[String] = [
    "res://sounds/whoosh_air.ogg",
    "res://sounds/whoosh_quickair.ogg",
]
const ABSORB_SFX_PATH := "res://sounds/usedrunesound.wav"

# --- 1. Release: the card presses in before it springs away ----------------------------------
# The effect has already fired when this starts (Card.play() resolves at release), so the flash
# says "that landed" and the press is the card's own recoil. The press lives on the ART only,
# never the root, so it cannot fight the glide.
const RESOLVE_FLASH_COLOR := Color(1.65, 1.55, 1.15, 1.0)
const RESOLVE_FLASH_DECAY := 0.3
const PRESS_TIME := 0.05
const PRESS_SCALE := Vector2(1.07, 0.9)
const PRESS_RELEASE_TIME := 0.24

# --- 2. Glide to the ONE fixed presentation spot (Julien's pick, 2026-07-18) -----------------
# The cursor is ignored on purpose: following it was the "up AND right" he kept seeing.
const STAGE_CENTER := Vector2(470.0, 405.0)
const GLIDE_TIME := 0.3
const STAGE_SCALE := 1.12

# --- 3. Hold, long enough to see the hits land -----------------------------------------------
# Thrown dice land 0.95s after the play and a volley can run 1.95s longer, while the card used to
# leave at ~0.6s and be gone by ~1s. The hold now stretches to cover the LAST delayed hit the play
# scheduled (Card.note_delayed_hit), plus a beat, capped so a big volley does not park a card on
# the stage for three seconds.
const HOLD_TIME := 0.24
const HOLD_MAX := 1.2
const HIT_BEAT := 0.12

# --- 4a. Exit: a swoosh into the pile, STS2 NCardFlyVfx-style --------------------------------
# The path bows BELOW the straight line to the pile, never above it: an up-and-over lob into a
# bottom-right pile reads as "up and right", which Julien rejected in July. The card turns to
# point along its path like a dart, and shrinks and darkens over the first third, so the bright
# ribbon carries the eye the rest of the way.
const EXIT_TIME_MIN := 0.36
const EXIT_TIME_MAX := 0.46
const EXIT_BOW_MIN := 45.0
const EXIT_BOW_MAX := 120.0
const EXIT_SHRINK_SHARE := 0.33
const EXIT_END_SCALE := 0.1
const EXIT_DARK := Color(0.34, 0.34, 0.38, 1.0)
const EXIT_TURN_RATE := 12.0
const ARRIVE_SHRINK_TIME := 0.08
# Quiet and low priority: this fires on every play, and the SFX pool steals low-priority voices
# first, so a whoosh can never cut the sound of the effect itself.
const WHOOSH_DB := -11.0
const WHOOSH_THROTTLE_MS := 90

# --- Ribbon and sparks ------------------------------------------------------------------------
const RIBBON_WIDTH := 22.0
const RIBBON_FIZZLE_COLOR := Color(0.5, 0.5, 0.56)
const SPARK_INTERVAL_MS := 55
const SPARK_LIFETIME := 0.3

# --- Fizzle: a play whose requirement missed, so nothing happened -----------------------------
# Only two ways to get here: a Red roll that misses the socketed card, and a card played blind
# under Ink. The pick-up refusal blocks every other miss before the drag starts. It borrows the
# refusal's language (red ribbon flash, the error sound) because it means the same thing.
const FIZZLE_HOLD := 0.5
const FIZZLE_GREY := Color(0.5, 0.5, 0.54, 1.0)
const FIZZLE_RIBBON_FLASH := Color(2.4, 0.85, 0.8, 1.0)
const FIZZLE_DROOP := 18.0
const FIZZLE_TILT := -0.11
const FIZZLE_SFX_DB := -10.0

# --- 4b. Absorb: a Blessing swirls into the hero, STS2 NCardFlyPowerVfx-style ----------------
# Every Blessing exhausts, so they all used to burn, which contradicted the tutorial's own line
# "The card is gone, but its effect stays." The card now rises, swings over and dives into the
# hero, facing its path with a turn rate that ramps up. The ramp tops out far below STS2's 50pi
# rad/s on purpose: Julien got dizzy from rotating dice, and the card is small by the time it
# turns hardest.
const ABSORB_SPEED := 1350.0
const ABSORB_TIME_MIN := 0.42
const ABSORB_TIME_MAX := 0.62
const ABSORB_LIFT := Vector2(40.0, -170.0)
const ABSORB_FALL := Vector2(120.0, -230.0)
const ABSORB_MIN_SCALE := 0.2
const ABSORB_SHRINK_SHARE := 0.45
const ABSORB_VANISH_SHARE := 0.12
const ABSORB_TURN_START := PI
const ABSORB_TURN_END := 14.0 * PI
const ABSORB_GLOW := Color(1.55, 1.4, 1.15, 1.0)
const ABSORB_FLARE_SIZE := 110.0
const ABSORB_SFX_DB := -8.0
# Shaker.Impact.WEAK, as a literal: an autoload's enum cannot be folded into a const.
const ABSORB_SHAKE_TIER := 1

# --- 4c. Burn (exhaust, 2026-09-23) -----------------------------------------------------------
# A card tree is a stack of Panels, Labels and RichTextLabels, and a shader on the root would not
# reach any of them. So the card is moved into a small SubViewport rendered to a texture, and the
# burn shader runs on a TextureRect standing exactly where the card was.
const BURN_HOLD := 0.1
const BURN_TIME := 0.62
const BURN_PAD := 16.0
const BURN_EMBER_COLOR := Color(1.0, 0.55, 0.18)
const BURN_EMBER_INTERVAL_MS := 22
const BURN_EMBER_LIFETIME := 0.55
const BURN_PILE_EMBER_AT := 0.55
const BURN_PILE_EMBER_TIME := 0.32

# Longest possible flight (press + glide + HOLD_MAX + the slowest route) with room to spare. Only
# matters when something kills the flight before it lands: the pile then counts the card anyway.
const ARRIVAL_FAILSAFE := 3.2

# Set by the caller before prepare()/start().
var ui_layer: Node = null
var art: Control = null
var route: int = Route.DISCARD
var fizzled := false
var hold_extra := 0.0
var pile_button: Control = null
var accent := Color.WHITE
var resolve_flash := true

var flyer: Control = null
var arrival_token := 0

var _prepared := false
var _phase := Phase.INTRO
var _press := Vector2.ONE
var _settle := 0.0
var _art_from_pos := Vector2.ZERO
var _art_from_rot := 0.0
var _art_from_scale := Vector2.ONE
# Untyped: setup()/stop() live on the ribbon's script, not on Line2D.
var _ribbon = null
var _ribbon_color := Color.WHITE
var _elapsed := 0.0
var _duration := 1.0
var _p0 := Vector2.ZERO
var _p1 := Vector2.ZERO
var _p2 := Vector2.ZERO
var _p3 := Vector2.ZERO
var _from_scale := 1.0
var _from_modulate := Color.WHITE
var _last_spark_ms := 0

static var _whoosh_streams: Array[AudioStream] = []
static var _last_whoosh_ms := -100000
static var _last_burn_ember_ms := 0
static var _last_pile_ember_ms := 0
static var _spark_texture: GradientTexture2D


# Synchronous half: tell the pile a card is on its way BEFORE the frame ends. The pile's contents
# already changed during the play, and the exhaust pile reveals itself at the end of the frame if
# it counts a card, so an expectation registered any later would let it pop up early.
func prepare() -> void:
    if _prepared:
        return
    _prepared = true
    if pile_button is CardPileOpener and is_instance_valid(pile_button):
        arrival_token = (pile_button as CardPileOpener).expect_arrival(ARRIVAL_FAILSAFE)


func start() -> void:
    prepare()
    flyer = get_parent() as Control
    if flyer == null:
        _land_pile(false)
        queue_free()
        return
    ignore_mouse(flyer)
    set_pivot_keep_visual(flyer, flyer.size * 0.5)
    if is_instance_valid(art):
        set_pivot_keep_visual(art, art.size * 0.5)
        _art_from_pos = art.position
        _art_from_rot = art.rotation
        _art_from_scale = art.scale
    _ribbon_color = RIBBON_FIZZLE_COLOR if fizzled else accent

    # Press, then spring back as the glide starts. Scale on the art only.
    _write_art()
    var press := create_tween()
    press.tween_method(_set_press, Vector2.ONE, PRESS_SCALE, PRESS_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    press.tween_method(_set_press, PRESS_SCALE, Vector2.ONE, PRESS_RELEASE_TIME) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    # Whatever pose the art was in (the hand's follower lag, the aim pose, the drag tilt) eases
    # back to the card's own frame over the glide instead of snapping.
    var settle := create_tween()
    settle.tween_interval(PRESS_TIME)
    settle.tween_method(_set_settle, 0.0, 1.0, GLIDE_TIME) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

    # A miss has nothing to announce, so it gets no resolve flash.
    if fizzled or not resolve_flash:
        flyer.modulate = Color.WHITE
    else:
        flyer.modulate = RESOLVE_FLASH_COLOR
        var flash := create_tween()
        flash.tween_property(flyer, "modulate", Color.WHITE, RESOLVE_FLASH_DECAY) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

    var glide := create_tween()
    glide.tween_interval(PRESS_TIME)
    glide.tween_property(flyer, "position", STAGE_CENTER - flyer.pivot_offset, GLIDE_TIME) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    glide.parallel().tween_property(flyer, "scale", Vector2.ONE * STAGE_SCALE, GLIDE_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    glide.parallel().tween_property(flyer, "rotation", 0.0, GLIDE_TIME * 0.6) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    glide.tween_callback(_on_stage)

    if ui_layer != null and is_instance_valid(ui_layer):
        _ribbon = RIBBON_SCRIPT.new()
        _ribbon.z_index = 95  # under every flying card (100)
        ui_layer.add_child(_ribbon)
        _ribbon.setup(art if is_instance_valid(art) else flyer, _ribbon_color, RIBBON_WIDTH)


# Which way a played card leaves. `exhausted` is the rules' decision (Card.last_play_report),
# never a fresh should_exhaust() after the play: the play can reset Power and flip it.
static func route_for(played: Card, exhausted: bool) -> int:
    if not exhausted:
        return Route.DISCARD
    if played != null and played.type == Card.Type.BLESSING:
        return Route.BLESSING
    return Route.BURN


# The pile the card is filed in. A Blessing enters the hero but is still counted in the Exhaust
# pile, which is where the rules put it.
static func pile_for(layer: Node, route_id: int) -> Control:
    if layer == null or not is_instance_valid(layer):
        return null
    var pile_name := "DiscardPileButton" if route_id == Route.DISCARD else "ExhaustPileButton"
    return layer.get_node_or_null(pile_name) as Control


# A flying card must not eat clicks. The hold can now keep one on the stage for over a second,
# right beside the die and its ROLL button, and the card's frame and the socket's panels all stop
# the mouse by default.
static func ignore_mouse(root: Node) -> void:
    if root is Control:
        (root as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in root.get_children():
        ignore_mouse(child)


static func hold_time_for(route_id: int, fizzle: bool, last_hit: float) -> float:
    var base: float = BURN_HOLD if route_id == Route.BURN else HOLD_TIME
    if fizzle:
        base = maxf(base, FIZZLE_HOLD)
    var to_cover: float = last_hit + HIT_BEAT - (PRESS_TIME + GLIDE_TIME)
    return clampf(maxf(base, to_cover), base, maxf(base, HOLD_MAX))


func _on_stage() -> void:
    if _phase == Phase.DONE:
        return
    if fizzled:
        _play_fizzle()
    var t := create_tween()
    t.tween_interval(hold_time_for(route, fizzled, hold_extra))
    t.tween_callback(_leave)


func _leave() -> void:
    match route:
        Route.BURN:
            _burn()
        Route.BLESSING:
            _begin_absorb()
        _:
            _begin_exit()


func _process(delta: float) -> void:
    if _phase == Phase.EXIT:
        _step_exit(delta)
    elif _phase == Phase.ABSORB:
        _step_absorb(delta)


# ------------------------------------------------------------------------------ art channel

func _set_press(v: Vector2) -> void:
    _press = v
    _write_art()


func _set_settle(v: float) -> void:
    _settle = v
    _write_art()


func _write_art() -> void:
    if not is_instance_valid(art):
        return
    art.position = _art_from_pos.lerp(Vector2.ZERO, _settle)
    art.rotation = lerpf(_art_from_rot, 0.0, _settle)
    art.scale = _art_from_scale.lerp(Vector2.ONE, _settle) * _press


# --------------------------------------------------------------------------------- fizzle

func _play_fizzle() -> void:
    SFXPlayer.play(FIZZLE_SFX, false, 0.82, FIZZLE_SFX_DB, -1)
    var ribbon_panel: Control = null
    if is_instance_valid(art):
        ribbon_panel = art.get_node_or_null("CardFrame/RequirementPanel") as Control
    if ribbon_panel != null and ribbon_panel.visible:
        ribbon_panel.pivot_offset = ribbon_panel.size * 0.5
        var rt := create_tween()
        rt.tween_property(ribbon_panel, "scale", Vector2(1.2, 1.2), 0.08) \
            .from(Vector2.ONE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        rt.parallel().tween_property(ribbon_panel, "modulate", FIZZLE_RIBBON_FLASH, 0.08)
        rt.tween_property(ribbon_panel, "scale", Vector2.ONE, 0.26) \
            .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
        rt.parallel().tween_property(ribbon_panel, "modulate", Color.WHITE, 0.3)
    # The ribbon gets its beat first, THEN the card goes grey and sags - a card that droops
    # while it flashes reads as one muddy event instead of "this is why, and so nothing".
    var t := create_tween()
    t.tween_interval(0.06)
    t.tween_property(flyer, "modulate", FIZZLE_GREY, 0.22) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(flyer, "position:y", flyer.position.y + FIZZLE_DROOP, 0.4) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(flyer, "rotation", FIZZLE_TILT, 0.4) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------------ exit into a pile

func _begin_exit() -> void:
    _p0 = _center()
    _p2 = _pile_target()
    var chord := _p2 - _p0
    var normal := Vector2(-chord.y, chord.x).normalized()
    if normal.y < 0.0:
        normal = -normal
    _p1 = (_p0 + _p2) * 0.5 + normal * randf_range(EXIT_BOW_MIN, EXIT_BOW_MAX)
    _duration = randf_range(EXIT_TIME_MIN, EXIT_TIME_MAX)
    _elapsed = 0.0
    _from_scale = flyer.scale.x
    _from_modulate = flyer.modulate
    _phase = Phase.EXIT
    play_whoosh()


func _step_exit(delta: float) -> void:
    _elapsed += delta
    var u: float = clampf(_elapsed / _duration, 0.0, 1.0)
    var s: float = u * u  # accelerates into the pile
    var pos := bezier2(_p0, _p1, _p2, s)
    flyer.position = pos - flyer.pivot_offset
    var ahead := bezier2(_p0, _p1, _p2, minf(s + 0.04, 1.0))
    var dir := ahead - pos
    if dir.length_squared() > 0.01:
        var target_rot: float = dir.angle() + PI * 0.5
        flyer.rotation = lerp_angle(flyer.rotation, target_rot, minf(delta * EXIT_TURN_RATE, 1.0))
    var k: float = clampf(u / EXIT_SHRINK_SHARE, 0.0, 1.0)
    var ke: float = 1.0 - (1.0 - k) * (1.0 - k)
    flyer.scale = Vector2.ONE * lerpf(_from_scale, _from_scale * EXIT_END_SCALE, ke)
    flyer.modulate = _from_modulate.lerp(EXIT_DARK, ke)
    _spark()
    if u >= 1.0:
        _arrive_at_pile()


func _arrive_at_pile() -> void:
    _phase = Phase.DONE
    _land_pile(true)
    _stop_ribbon()
    var t := create_tween()
    t.tween_property(flyer, "scale", Vector2.ZERO, ARRIVE_SHRINK_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.tween_callback(flyer.queue_free)


# ------------------------------------------------------------------ absorb into the hero

func _begin_absorb() -> void:
    var hero_v = Global.player
    if not is_instance_valid(hero_v) or not (hero_v is Node2D) or not (hero_v as Node2D).is_inside_tree():
        # Nowhere to go: file it like any other card.
        _begin_exit()
        return
    var hero := hero_v as Node2D
    _p0 = _center()
    _p3 = hero.get_viewport().get_canvas_transform() * Card.thrown_impact_pos(hero)
    _p1 = _p0 + ABSORB_LIFT
    _p2 = _p3 + ABSORB_FALL
    var length := 0.0
    var prev := _p0
    for i in range(1, 17):
        var q := bezier3(_p0, _p1, _p2, _p3, float(i) / 16.0)
        length += prev.distance_to(q)
        prev = q
    _duration = clampf(length / ABSORB_SPEED, ABSORB_TIME_MIN, ABSORB_TIME_MAX)
    _elapsed = 0.0
    _from_scale = flyer.scale.x
    _from_modulate = flyer.modulate
    _phase = Phase.ABSORB
    play_whoosh()


func _step_absorb(delta: float) -> void:
    _elapsed += delta
    var u: float = clampf(_elapsed / _duration, 0.0, 1.0)
    var s: float = u * u
    var pos := bezier3(_p0, _p1, _p2, _p3, s)
    flyer.position = pos - flyer.pivot_offset
    var ahead := bezier3(_p0, _p1, _p2, _p3, minf(s + 0.03, 1.0))
    var dir := ahead - pos
    if dir.length_squared() > 0.01:
        var target_rot: float = dir.angle() + PI * 0.5
        var max_turn: float = lerpf(ABSORB_TURN_START, ABSORB_TURN_END, u) * delta
        var diff: float = wrapf(target_rot - flyer.rotation, -PI, PI)
        flyer.rotation += clampf(diff, -max_turn, max_turn)
    var k: float = clampf(u / ABSORB_SHRINK_SHARE, 0.0, 1.0)
    var sc: float = lerpf(_from_scale, _from_scale * ABSORB_MIN_SCALE, 1.0 - (1.0 - k) * (1.0 - k))
    if u > 1.0 - ABSORB_VANISH_SHARE:
        sc *= clampf((1.0 - u) / ABSORB_VANISH_SHARE, 0.0, 1.0)
    flyer.scale = Vector2.ONE * sc
    flyer.modulate = _from_modulate.lerp(ABSORB_GLOW, u)
    _spark()
    if u >= 1.0:
        _arrive_in_hero()


func _arrive_in_hero() -> void:
    _phase = Phase.DONE
    var hero_v = Global.player
    if is_instance_valid(hero_v) and hero_v.has_method("play_flex"):
        hero_v.play_flex()
    # Untyped on purpose: shake() lives on the battle camera's script, not on Node.
    var camera = get_tree().get_first_node_in_group("camera")
    if camera != null and camera.has_method("shake"):
        var mag: float = Shaker.SHAKE_MAGNITUDE[ABSORB_SHAKE_TIER]
        var dur: float = Shaker.SHAKE_DURATION[ABSORB_SHAKE_TIER]
        camera.shake(mag, dur)
    if ui_layer != null and is_instance_valid(ui_layer):
        _spawn_flare(ui_layer, _p3, _ribbon_color.lerp(Color.WHITE, 0.5), ABSORB_FLARE_SIZE)
    var sfx := load(ABSORB_SFX_PATH) as AudioStream
    if sfx != null:
        SFXPlayer.play(sfx, false, 1.15, ABSORB_SFX_DB)
    _land_pile(true, 1.1)
    _stop_ribbon()
    flyer.queue_free()


# ---------------------------------------------------------------------------------- burn

func _burn() -> void:
    _phase = Phase.DONE
    _stop_ribbon()
    if ui_layer == null or not is_instance_valid(ui_layer):
        _land_pile(true)
        flyer.queue_free()
        return
    var xf := flyer.get_global_transform()
    var center: Vector2 = xf * (flyer.size / 2.0)
    var s: float = xf.get_scale().x
    var card_px := flyer.size * s

    var vp := SubViewport.new()
    vp.transparent_bg = true
    vp.disable_3d = true
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    vp.size = Vector2i(ceili(card_px.x + BURN_PAD * 2.0), ceili(card_px.y + BURN_PAD * 2.0))
    ui_layer.add_child(vp)

    var display := TextureRect.new()
    display.texture = vp.get_texture()
    display.mouse_filter = Control.MOUSE_FILTER_IGNORE
    display.size = Vector2(vp.size)
    display.position = center - display.size / 2.0
    display.z_index = 100
    var mat := ShaderMaterial.new()
    mat.shader = BURN_SHADER
    var pad_uv := Vector2(BURN_PAD, BURN_PAD) / Vector2(vp.size)
    mat.set_shader_parameter("card_uv_min", pad_uv)
    mat.set_shader_parameter("card_uv_max", Vector2.ONE - pad_uv)
    mat.set_shader_parameter("ember_color", BURN_EMBER_COLOR)
    mat.set_shader_parameter("progress", 0.0)
    display.material = mat
    ui_layer.add_child(display)

    # Into the viewport: upright, centred, at the scale it was drawn at on screen, art at rest.
    _settle = 1.0
    _press = Vector2.ONE
    _write_art()
    flyer.reparent(vp, false)
    flyer.rotation = 0.0
    flyer.pivot_offset = flyer.size / 2.0
    flyer.scale = Vector2(s, s)
    flyer.position = Vector2(vp.size) / 2.0 - flyer.size / 2.0

    # Everything below is owned by nodes that outlive this card (the display, the pile button),
    # so nothing is left calling into a freed card.
    var layer := ui_layer
    var burn := display.create_tween()
    burn.tween_method(func(p: float) -> void: mat.set_shader_parameter("progress", p), 0.0, 1.0, BURN_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    burn.parallel().tween_method(func(p: float) -> void: _burn_ember_step(p, layer, center, card_px),
            0.0, 1.0, BURN_TIME)
    burn.tween_callback(vp.queue_free)
    burn.tween_callback(display.queue_free)
    var pile := pile_button
    var token := arrival_token
    arrival_token = 0
    if pile != null and is_instance_valid(pile):
        var ember_timer := display.create_tween()
        ember_timer.tween_interval(BURN_TIME * BURN_PILE_EMBER_AT)
        ember_timer.tween_callback(func() -> void: _send_ember_to_pile(layer, center, pile, token))


# Embers peel off the burning edge: a random point on the card's border, drawn inward as the burn
# eats toward the middle, drifting up and dying out. Throttled on the real clock like the trails.
static func _burn_ember_step(p: float, layer: Node, center: Vector2, card_px: Vector2) -> void:
    if not is_instance_valid(layer):
        return
    var now := Time.get_ticks_msec()
    if now - _last_burn_ember_ms < BURN_EMBER_INTERVAL_MS:
        return
    _last_burn_ember_ms = now
    var half := card_px / 2.0 * (1.0 - 0.85 * p)
    var point: Vector2
    if randf() < 0.5:
        point = Vector2(randf_range(-half.x, half.x), half.y * (1.0 if randf() < 0.5 else -1.0))
    else:
        point = Vector2(half.x * (1.0 if randf() < 0.5 else -1.0), randf_range(-half.y, half.y))
    _spawn_ember(layer, center + point, randf_range(8.0, 16.0),
            Vector2(randf_range(-10.0, 10.0), -randf_range(26.0, 60.0)))


static func _spawn_ember(layer: Node, at: Vector2, size_px: float, drift: Vector2) -> void:
    var mote := _make_glow_rect(Color(BURN_EMBER_COLOR.r * 1.6, BURN_EMBER_COLOR.g * 1.6,
            BURN_EMBER_COLOR.b * 1.6, 0.95), 101)
    layer.add_child(mote)
    mote.size = Vector2(size_px, size_px)
    mote.pivot_offset = mote.size / 2.0
    mote.position = at - mote.size / 2.0
    var t := mote.create_tween()
    t.tween_property(mote, "position", mote.position + drift, BURN_EMBER_LIFETIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(mote, "modulate:a", 0.0, BURN_EMBER_LIFETIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.parallel().tween_property(mote, "scale", Vector2(0.3, 0.3), BURN_EMBER_LIFETIME)
    t.tween_callback(mote.queue_free)


# The pile still has to say where the card went: one bright ember streaks into it, and the pile
# counts the card when that ember lands.
static func _send_ember_to_pile(layer: Node, from: Vector2, pile_button: Control, token: int) -> void:
    if not is_instance_valid(layer) or not is_instance_valid(pile_button):
        return
    var to := pile_button.get_global_rect().get_center()
    var ember := _make_glow_rect(Color(1.9, 1.2, 0.55, 1.0), 102)
    layer.add_child(ember)
    ember.size = Vector2(26.0, 26.0)
    ember.position = from - ember.size / 2.0
    var t := ember.create_tween()
    t.tween_property(ember, "position", to - ember.size / 2.0, BURN_PILE_EMBER_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.parallel().tween_method(func(_x: float) -> void:
        if not is_instance_valid(ember) or not is_instance_valid(layer):
            return
        var now := Time.get_ticks_msec()
        if now - _last_pile_ember_ms < BURN_EMBER_INTERVAL_MS:
            return
        _last_pile_ember_ms = now
        _spawn_ember(layer, ember.position + ember.size / 2.0, randf_range(7.0, 12.0), Vector2(0.0, -8.0)),
        0.0, 1.0, BURN_PILE_EMBER_TIME)
    t.tween_callback(ember.queue_free)
    # On the PILE's own tween, so the count lands even though the ember is freed on arrival.
    if pile_button is CardPileOpener:
        var pile := pile_button as CardPileOpener
        var land := pile.create_tween()
        land.tween_interval(BURN_PILE_EMBER_TIME)
        if token != 0:
            land.tween_callback(pile.land_arrival.bind(token, true, 1.18))
        else:
            land.tween_callback(pile.receive_punch)


# ------------------------------------------------------------------------------- helpers

func _center() -> Vector2:
    return flyer.position + flyer.pivot_offset


func _art_center() -> Vector2:
    if is_instance_valid(art) and art.is_inside_tree():
        return art.get_global_transform() * (art.size * 0.5)
    return _center()


func _pile_target() -> Vector2:
    if pile_button != null and is_instance_valid(pile_button):
        return pile_button.get_global_rect().get_center()
    return _center() + Vector2(0.0, 220.0)


func _land_pile(punch: bool, strength: float = 1.18) -> void:
    if not (pile_button is CardPileOpener) or not is_instance_valid(pile_button):
        return
    var pile := pile_button as CardPileOpener
    if arrival_token != 0:
        pile.land_arrival(arrival_token, punch, strength)
        arrival_token = 0
    elif punch:
        pile.receive_punch(strength)


func _stop_ribbon() -> void:
    if _ribbon != null and is_instance_valid(_ribbon):
        _ribbon.stop()


# A few sparks off the head of the ribbon while the card travels - most of the old mote cloud is
# gone, these are what is left of it.
func _spark() -> void:
    if ui_layer == null or not is_instance_valid(ui_layer):
        return
    var now := Time.get_ticks_msec()
    if now - _last_spark_ms < SPARK_INTERVAL_MS:
        return
    _last_spark_ms = now
    var color := _ribbon_color.lerp(Color.WHITE, 0.35)
    var spark := _make_glow_rect(Color(color.r, color.g, color.b, 0.9), 96)
    ui_layer.add_child(spark)
    var s := randf_range(7.0, 13.0)
    spark.size = Vector2(s, s)
    spark.pivot_offset = spark.size / 2.0
    spark.position = _art_center() - spark.size / 2.0
    var drift := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(10.0, 24.0)
    var t := spark.create_tween()
    t.tween_property(spark, "position", spark.position + drift, SPARK_LIFETIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(spark, "modulate:a", 0.0, SPARK_LIFETIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.parallel().tween_property(spark, "scale", Vector2(0.3, 0.3), SPARK_LIFETIME)
    t.tween_callback(spark.queue_free)


static func _spawn_flare(layer: Node, at: Vector2, color: Color, size_px: float) -> void:
    var flare := _make_glow_rect(Color(color.r, color.g, color.b, 0.9), 97)
    layer.add_child(flare)
    flare.size = Vector2(size_px, size_px)
    flare.pivot_offset = flare.size / 2.0
    flare.position = at - flare.size / 2.0
    flare.scale = Vector2(0.5, 0.5)
    var t := flare.create_tween()
    t.tween_property(flare, "scale", Vector2(1.4, 1.4), 0.3) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(flare, "modulate:a", 0.0, 0.3) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t.tween_callback(flare.queue_free)


static func _make_glow_rect(color: Color, z: int) -> TextureRect:
    var rect := TextureRect.new()
    rect.texture = _glow_texture()
    # Fixed 32x32 source: without EXPAND_IGNORE_SIZE it renders at native size whatever .size says.
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.material = DicePalette.additive_material()
    rect.modulate = color
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.z_index = z
    return rect


static func _glow_texture() -> GradientTexture2D:
    if _spark_texture != null:
        return _spark_texture
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
    _spark_texture = tex
    return _spark_texture


static func play_whoosh() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_whoosh_ms < WHOOSH_THROTTLE_MS:
        return
    _last_whoosh_ms = now
    if _whoosh_streams.is_empty():
        for path: String in WHOOSH_PATHS:
            var stream := load(path) as AudioStream
            if stream != null:
                _whoosh_streams.append(stream)
    if _whoosh_streams.is_empty():
        return
    SFXPlayer.play(_whoosh_streams[randi() % _whoosh_streams.size()], false,
            randf_range(1.12, 1.28), WHOOSH_DB, -1)


# Moves a Control's pivot without moving what is on screen. A Control draws as
# translate(position + pivot) * R * S * translate(-pivot), so a scaled or turned card jumps when
# its pivot changes - a card hovered at 1.12 used to hop ~10px the moment it was played.
static func set_pivot_keep_visual(c: Control, pivot: Vector2) -> void:
    var old := c.pivot_offset
    if old.is_equal_approx(pivot):
        return
    var rs := Transform2D(c.rotation, c.scale, 0.0, Vector2.ZERO)
    c.position += (old - rs.basis_xform(old)) - (pivot - rs.basis_xform(pivot))
    c.pivot_offset = pivot


static func bezier2(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
    var u := 1.0 - t
    return a * (u * u) + b * (2.0 * u * t) + c * (t * t)


static func bezier3(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
    var u := 1.0 - t
    return a * (u * u * u) + b * (3.0 * u * u * t) + c * (3.0 * u * t * t) + d * (t * t * t)
