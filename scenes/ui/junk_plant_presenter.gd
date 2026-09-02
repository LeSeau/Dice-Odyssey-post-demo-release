extends Control

# JunkPlantPresenter (2026-09-02) - the story of an enemy writing a card into your deck.
#
# Owned by BattleUI (built in code, no .tscn, no class_name - same shape as
# card_inspect_overlay.gd, so nothing needs an editor rescan). BattleUI forwards
# Events.add_card_to_discard_requested / add_card_to_draw_pile_requested into plant(); the
# pile WRITE itself is player_handler's, done on the emit - this only ever tells the player
# what has already happened, and can never fire without the write.
#
# What it has to make readable, in Julien's words: "exactly WHICH cards, HOW MANY, and WHERE
# they went, on the enemy's move". The previous flourish (a 38px crop of the art arcing to
# the discard) said none of the three: too small to name the card, one blob per card, and
# no word about the pile. So:
#   WHICH  - a real CardMenuUI face, the card's own Hex chrome, held at 1.15x on the stage
#            spot every played card already presents at (card_ui.gd STAGE_HOLD_CENTER):
#            the place the eye is trained to read a card. The ash/iron chrome is what says
#            "not one of yours" while it sits there.
#   HOW MANY - one face per card, fanned side by side (up to MAX_VISIBLE_CARDS), and the
#            caption counts them: "2x Slander added to your Discard pile". Cards planted in
#            the same FRAME batch into one fan (a multi-card action); anything later gets
#            its own presentation, queued behind the current one so two never share the
#            stage.
#   WHERE  - the caption names the pile, and the pile itself answers: the card streaks
#            into it, it punches on the catch and a ring of light pulses out of it.
# The whole beat runs during the planting enemy's hold (Global.JUNK_PLANT_PRESENT_TIME):
# the enemy stands there while you read, and walks back exactly as the card flies off. The
# conjure + glide + hold are carved OUT of that budget, never added on top.
#
# Colour: ACCENT is the muted violet of hex.png itself - deliberately none of the nine dice
# accents (cobalt Blue, fuchsia Evil, light-steel Mech are the near misses), so the trail
# can never read as one of the player's own dice flourishes.

signal presentation_started(count: int, dest: int)
signal card_landed(pile: CardPileOpener)
signal presentation_finished(count: int, dest: int)

enum Dest { DRAW, DISCARD }

const CARD_MENU_UI := preload("res://scenes/ui/card_menu_ui.tscn")
const CAPTION_FONT: FontFile = preload("res://fonts/MinionPro-Bold.otf")
const CARD_SIZE := Vector2(140, 210)

const ACCENT := Color(0.62, 0.50, 0.86)
# The colour every additive light here is drawn in. Components deliberately <= 1.0: the dice
# trails push their accent to x1.6 and survive because blue has one low channel, but a violet
# has TWO high channels, and the renderer clamps each to 1 - measured on the strip, the aura
# came out R:G:B = 1 : 0.92 : 0.99, i.e. white haze. Brightness is carried by alpha instead.
const LIGHT := Color(0.66, 0.42, 1.0)

# --- beats (all game time) ----------------------------------------------------------
# Conjure at the enemy: a TRANS_BACK pop that finishes most of its travel in its first fifth -
# exactly what "it appeared out of the whisper" wants.
const CONJURE_TIME := 0.16
const CONJURE_SCALE := 0.5
const CONJURE_STAGGER := 0.05      # per extra card in a fan
const CONJURE_TILT_DEG := 14.0     # born askew, rights itself on the glide
# Glide to the stage: decelerating cubic, no overshoot - a card arriving to be read.
const GLIDE_TIME := 0.28
const STAGE_CENTER := Vector2(470.0, 425.0)  # a touch below the played-card spot: the hand is empty during the enemy turn, so the bottom band is free
# Fans lean left and shrink a step so the RIGHT card stays off the ROLL plate (x >= 521): at
# the first numbers (-20 / 110 / 1.0) the second face sat 54px over it, measured on the strip.
const FAN_CENTER_SHIFT := Vector2(-55.0, 0.0)
const FAN_SPACING := 104.0         # at scale 1.0; cards overlap ~36px, reads as a fan not a row
const FAN_TILT_DEG := 5.0
const HOLD_SCALE_BY_COUNT: Array[float] = [1.15, 0.95, 0.82]  # 1 card / 2 cards / 3+
const HOLD_EXTRA_PER_CARD := 0.15  # more to read, a little more time
const HOLD_MAX := 1.4
const HOLD_RISE := 6.0             # a frozen card reads as a dead image; the act banner's slow drift, in miniature
# Violet aura behind the face while it is presented - light, not stuff (Julien's glow
# doctrine): an additive radial stretched to the card's 2:3, whose centre hides under the
# opaque body so only a breathing rim shows. A child of the face, so it scales, tilts and
# shrinks into the pile with it. Kept faint: it separates the card from a dim act-2 room and
# says "cursed object", it must never become a lid.
const AURA_SCALE := Vector2(1.7, 1.5)
const AURA_ALPHA_LOW := 0.36
const AURA_ALPHA_HIGH := 0.62
const AURA_BREATH := 0.55
# Exit: a comet streak into the pile, accelerating (pulled in), shrinking, banked toward the pile.
const EXIT_TIME := 0.42
const EXIT_STAGGER := 0.09
const EXIT_END_SCALE := 0.12
const EXIT_BANK_DEG := 20.0
const EXIT_FADE := 0.16            # only the last stretch - the card stays visible travelling
const MAX_VISIBLE_CARDS := 4

# --- caption ------------------------------------------------------------------------
const CAPTION_FONT_SIZE := 24
const CAPTION_GAP := 26.0          # below the fan's bottom edge
const CAPTION_IN_TIME := 0.18
const CAPTION_FADE := 0.3

# --- light --------------------------------------------------------------------------
const FLARE_SIZE := 110.0          # cast pop at the enemy
const FLARE_TIME := 0.24
const BLOOM_SIZE := 120.0          # catch pop at the pile
const BLOOM_TIME := 0.26
const RING_SIZE := 210.0           # expanding ring behind the pile button, twice
const RING_PULSES := 2
const RING_PERIOD := 0.4
const MOTE_INTERVAL_MS := 20       # real-time throttle: the exit accelerates, a t-based gap would clump
const MOTE_SIZE_MIN := 14.0
const MOTE_SIZE_MAX := 26.0
const MOTE_LIFETIME := 0.4
const MOTE_ALPHA := 0.9
const MOTE_SCATTER := 20.0
const LAND_PUNCH := 1.25

# Placeholders, both. Conjure = the pluck pitched well down (an ominous, dull note); land =
# the draw tick pitched down and quiet. Wants a proper "unwanted card" pair.
const CONJURE_SFX := preload("res://sfx/578807__nomiqbomi__pluck-1.mp3")
const CONJURE_SFX_PITCH := 0.62
const CONJURE_SFX_DB := -7.0
const LAND_SFX := preload("res://drawcardsound.wav")
const LAND_SFX_PITCH := 0.8
const LAND_SFX_DB := -4.0

# Above the End Turn button (40) and the hand's flying cards (100), under the scout FX (149+).
const Z_BASE := 118
const Z_FX := 0
const Z_CARD := 2
const Z_CAPTION := 3

var draw_pile_button: CardPileOpener
var discard_pile_button: CardPileOpener

var _pending: Array[Dictionary] = []
var _flush_scheduled := false
var _queue: Array = []
var _busy := false
var _caption: Label


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Keeps animating through a pause: if the plant is the blow that ends the fight, the tree
    # pauses for the game-over panel and a pausable owner would strand the card mid-air.
    process_mode = Node.PROCESS_MODE_ALWAYS
    z_index = Z_BASE
    set_anchors_preset(Control.PRESET_FULL_RECT)


# Entry point. `source_global_position` is a WORLD position (the planting enemy's sprite
# centre); Vector2.ZERO means "no on-screen source" and skips the flight (harness, or a
# non-enemy injector), acknowledging the pile with a punch so the write is never invisible.
func plant(card: Card, source_global_position: Vector2, dest: int) -> void:
    if card == null:
        return
    _pending.append({"card": card, "origin": source_global_position, "dest": dest})
    # One frame of collection: a multi-card action emits in a loop, same frame, and those
    # belong in ONE fan with ONE count. Anything arriving later is a different move.
    if not _flush_scheduled:
        _flush_scheduled = true
        call_deferred("_flush_pending")


func is_presenting() -> bool:
    return _busy


# Time from emit to the moment the fan leaves the stage. For a single card this is EXACTLY
# Global.JUNK_PLANT_PRESENT_TIME (the enemy's hold); extra cards buy a little more reading
# time and the enemy may walk back slightly early - a multi-card plant is a bigger event.
static func hold_time_for(count: int) -> float:
    var base: float = Global.JUNK_PLANT_PRESENT_TIME - CONJURE_TIME - GLIDE_TIME
    return minf(base + HOLD_EXTRA_PER_CARD * float(maxi(count, 1) - 1), HOLD_MAX)


static func stage_time_for(count: int) -> float:
    return CONJURE_TIME + GLIDE_TIME + hold_time_for(count)


static func pile_display_name(dest: int) -> String:
    return "Draw pile" if dest == Dest.DRAW else "Discard pile"


# Caption copy. One distinct card name -> it is named ("Slander added to your Discard
# pile", "2x Slander added to ..."); a mixed batch falls back to the count alone.
static func caption_text_for(cards: Array, dest: int) -> String:
    var names := {}
    for card in cards:
        if card is Card:
            names[(card as Card).name] = true
    var count := cards.size()
    var pile := pile_display_name(dest)
    if names.size() == 1:
        var only: String = names.keys()[0]
        if count == 1:
            return "%s added to your %s" % [only, pile]
        return "%d× %s added to your %s" % [count, only, pile]
    return "%d cards added to your %s" % [count, pile]


# ---------------------------------------------------------------- sequencing

func _flush_pending() -> void:
    _flush_scheduled = false
    if _pending.is_empty():
        return
    # Split by destination, preserving arrival order: a fan has ONE caption, so it can only
    # ever name one pile.
    var by_dest := {}
    var order: Array = []
    for entry: Dictionary in _pending:
        var dest: int = entry["dest"]
        if not by_dest.has(dest):
            by_dest[dest] = []
            order.append(dest)
        by_dest[dest].append(entry)
    _pending.clear()
    for dest in order:
        _queue.append(by_dest[dest])
    _try_next()


func _try_next() -> void:
    if _busy or _queue.is_empty():
        return
    _busy = true
    _present(_queue.pop_front())


func _finish(count: int, dest: int) -> void:
    _busy = false
    presentation_finished.emit(count, dest)
    _try_next()


func _pile_for(dest: int) -> CardPileOpener:
    var pile := draw_pile_button if dest == Dest.DRAW else discard_pile_button
    return pile if is_instance_valid(pile) else null


# Enemies live in the base canvas (moved by the battle Camera2D); this presenter is on the
# BattleUI CanvasLayer in screen space, so a world origin has to be converted first.
# Every position below is then a raw `position` in THIS node's space - it sits unscaled at
# the layer origin, so that IS screen space. Never `global_position` here: on a Control that
# is scaled or rotated about a pivot, that getter/setter pair works on the TRANSFORMED corner
# (getter = position + pivot - R*S*pivot), so at conjure scale 0 the card was born a whole
# pivot away from the enemy and the exit would have "landed" ~110px up-left of the pile.
# The visual centre of a face is always `position + pivot_offset`, at any scale or tilt.
func _to_screen(world: Vector2) -> Vector2:
    return get_viewport().get_canvas_transform() * world


# ---------------------------------------------------------------- the presentation

func _present(batch: Array) -> void:
    var dest: int = batch[0]["dest"]
    var pile := _pile_for(dest)
    var count := batch.size()
    var has_origin := true
    for entry: Dictionary in batch:
        if entry["origin"] == Vector2.ZERO:
            has_origin = false
    if pile == null or not has_origin:
        if pile != null:
            pile.receive_punch(1.12)
        _finish(count, dest)
        return

    presentation_started.emit(count, dest)
    var visible_n := mini(count, MAX_VISIBLE_CARDS)
    var hold_scale: float = HOLD_SCALE_BY_COUNT[mini(visible_n, HOLD_SCALE_BY_COUNT.size()) - 1]
    var stage := STAGE_CENTER if visible_n == 1 else STAGE_CENTER + FAN_CENTER_SHIFT
    var spacing := FAN_SPACING * hold_scale
    var hold := hold_time_for(count)
    var pile_center := pile.global_position + pile.size / 2.0
    var bright := LIGHT

    SFXPlayer.play(CONJURE_SFX, false, CONJURE_SFX_PITCH, CONJURE_SFX_DB)

    var cards: Array = []
    for entry: Dictionary in batch:
        cards.append(entry["card"])

    for i in visible_n:
        var entry: Dictionary = batch[i]
        var ui := _make_card_face(entry["card"])
        var origin := _to_screen(entry["origin"])
        ui.position = origin - ui.pivot_offset
        ui.scale = Vector2.ZERO
        ui.rotation = deg_to_rad(randf_range(-CONJURE_TILT_DEG, CONJURE_TILT_DEG))

        var lane := float(i) - float(visible_n - 1) / 2.0
        var slot := stage + Vector2(lane * spacing, 0.0)
        var slot_rot := deg_to_rad(lane * FAN_TILT_DEG)
        # Every card leaves the stage at stage_time + EXIT_STAGGER * i, whatever its conjure
        # stagger was, so the fan flies off as a sequence rather than a clump.
        var hold_i := hold + (EXIT_STAGGER - CONJURE_STAGGER) * float(i)
        var bank := EXIT_BANK_DEG if pile_center.x > slot.x else -EXIT_BANK_DEG
        var trail_state := {"last_ms": 0}

        var t := create_tween()
        t.tween_interval(CONJURE_STAGGER * i)
        # 1. CONJURE - flare at the source, the face pops out of it askew.
        t.tween_callback(_spawn_flare.bind(origin, bright, FLARE_SIZE, FLARE_TIME))
        t.tween_property(ui, "scale", Vector2.ONE * CONJURE_SCALE, CONJURE_TIME) \
            .from(Vector2.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        # 2. GLIDE - to its slot on the stage, growing to reading size and righting itself.
        t.tween_property(ui, "position", slot - ui.pivot_offset, GLIDE_TIME) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        t.parallel().tween_property(ui, "scale", Vector2.ONE * hold_scale, GLIDE_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        t.parallel().tween_property(ui, "rotation", slot_rot, GLIDE_TIME * 0.7) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        # 3. HOLD - readable, with a slow rise so it is alive rather than frozen.
        t.tween_property(ui, "position:y", slot.y - HOLD_RISE - ui.pivot_offset.y, hold_i) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        # 4. EXIT - comet streak into the pile, trail shed at the live position.
        t.tween_property(ui, "position", pile_center - ui.pivot_offset, EXIT_TIME) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        t.parallel().tween_property(ui, "scale", Vector2.ONE * EXIT_END_SCALE, EXIT_TIME) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        t.parallel().tween_property(ui, "rotation", deg_to_rad(bank), EXIT_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        t.parallel().tween_property(ui, "modulate:a", 0.0, EXIT_FADE).set_delay(EXIT_TIME - EXIT_FADE)
        t.parallel().tween_method(_trail_step.bind(ui, trail_state), 0.0, 1.0, EXIT_TIME)
        # 5. CATCH - punch, bloom, ring on the first, caption out + finish on the last.
        t.tween_callback(_on_card_landed.bind(pile, pile_center, bright, i, visible_n, count, dest))
        t.tween_callback(ui.queue_free)

    # The caption arrives as the fan settles - naming the pile once there is something to name.
    var caption_center := Vector2(stage.x, stage.y + CARD_SIZE.y / 2.0 * hold_scale + CAPTION_GAP)
    var caption_tween := create_tween()
    caption_tween.tween_interval(CONJURE_TIME + GLIDE_TIME * 0.5)
    caption_tween.tween_callback(_show_caption.bind(caption_text_for(cards, dest), caption_center))


func _on_card_landed(pile: CardPileOpener, pile_center: Vector2, bright: Color, index: int, visible_n: int, count: int, dest: int) -> void:
    if is_instance_valid(pile):
        pile.receive_punch(LAND_PUNCH)
        if index == 0:
            _spawn_pile_ring(pile)
        card_landed.emit(pile)
    _spawn_flare(pile_center, bright, BLOOM_SIZE, BLOOM_TIME)
    SFXPlayer.play(LAND_SFX, false, LAND_SFX_PITCH + 0.05 * float(index), LAND_SFX_DB)
    if index == visible_n - 1:
        _hide_caption_then_finish(count, dest)


# ---------------------------------------------------------------- pieces

func _make_card_face(card: Card) -> Control:
    var ui: Control = CARD_MENU_UI.instantiate()
    ui.set("interactive", false)
    ui.set("disable_hover_tooltip", true)
    add_child(ui)
    ui.set("card", card)
    # card_menu_ui.tscn bakes scale = (2, 2) on its root; free of any container, nothing
    # resets it, so it is set explicitly here (and again on every beat above).
    ui.size = CARD_SIZE
    ui.pivot_offset = CARD_SIZE / 2.0
    ui.z_index = Z_CARD
    _add_aura(ui)
    # Visuals/CardFrame are mouse PASS in the scene: without this a cursor crossing the
    # flight would swap the hover stylebox on a card that is not there to be hovered.
    _ignore_mouse(ui)
    return ui


# Parented under Visuals (a plain Control), NEVER under the face's root: that root is a
# CenterContainer, and a child with a bigger minimum size grows the container itself, which
# re-centres the drawn card ~50px down-right of where position+pivot says it is (and on top
# of its own caption) - seen on the strip, invisible to any check that reads position. First
# child of Visuals, so it paints behind the card body, and it rides the face's transform.
func _add_aura(ui: Control) -> void:
    var visuals: Control = ui.get_node("Visuals")
    var aura := _make_light(1.0, LIGHT)
    aura.stretch_mode = TextureRect.STRETCH_SCALE
    aura.size = CARD_SIZE * AURA_SCALE
    aura.position = (CARD_SIZE - aura.size) / 2.0
    aura.modulate.a = AURA_ALPHA_LOW
    visuals.add_child(aura)
    visuals.move_child(aura, 0)
    var t := aura.create_tween()
    t.set_loops()
    t.tween_property(aura, "modulate:a", AURA_ALPHA_HIGH, AURA_BREATH)         .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    t.tween_property(aura, "modulate:a", AURA_ALPHA_LOW, AURA_BREATH)         .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _ignore_mouse(node: Node) -> void:
    if node is Control:
        (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in node.get_children():
        _ignore_mouse(child)


func _show_caption(text: String, center: Vector2) -> void:
    if is_instance_valid(_caption):
        _caption.queue_free()
    var label := Label.new()
    var settings := LabelSettings.new()
    settings.font = CAPTION_FONT
    settings.font_size = CAPTION_FONT_SIZE
    # The Hex title's ash on near-black: the caption wears the card's own "not yours" voice
    # rather than the gold every player-side banner speaks in.
    settings.font_color = CardMenuUI.HEX_TITLE_COLOR
    settings.outline_size = 5
    settings.outline_color = CardMenuUI.HEX_TITLE_OUTLINE_COLOR
    settings.shadow_size = 6
    settings.shadow_color = Color(0, 0, 0, 0.7)
    settings.shadow_offset = Vector2(2, 2)
    label.label_settings = settings
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.z_index = Z_CAPTION
    add_child(label)
    label.size = label.get_minimum_size()
    label.pivot_offset = label.size / 2.0
    label.position = center - label.size / 2.0
    label.modulate.a = 0.0
    label.scale = Vector2(0.7, 0.7)
    _caption = label
    var t := create_tween()
    t.tween_property(label, "modulate:a", 1.0, CAPTION_IN_TIME * 0.7)
    t.parallel().tween_property(label, "scale", Vector2.ONE, CAPTION_IN_TIME) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# The caption outlives the flight on purpose - it keeps naming the pile until the last card
# is caught - and only then fades. finish is chained after the fade so a listener that
# checks for leftovers on presentation_finished sees none.
func _hide_caption_then_finish(count: int, dest: int) -> void:
    if not is_instance_valid(_caption):
        _finish(count, dest)
        return
    var label := _caption
    _caption = null
    var t := create_tween()
    t.tween_property(label, "modulate:a", 0.0, CAPTION_FADE) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.tween_callback(label.queue_free)
    t.tween_callback(_finish.bind(count, dest))


func _make_light(size: float, color: Color) -> TextureRect:
    var fx := TextureRect.new()
    fx.texture = DicePalette.glow_texture()
    fx.material = DicePalette.additive_material()
    fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    fx.size = Vector2(size, size)
    fx.pivot_offset = fx.size / 2.0
    fx.modulate = color
    fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fx.z_index = Z_FX
    return fx


# One-shot pop of light. Alpha gets its own shorter, front-loaded curve so it is a FLASH -
# fading it across the whole expansion holds a white ball over whatever is underneath.
func _spawn_flare(pos: Vector2, color: Color, size: float, duration: float) -> void:
    var flare := _make_light(size, color)
    add_child(flare)
    flare.position = pos - flare.size / 2.0
    flare.scale = Vector2(0.3, 0.3)
    var t := flare.create_tween()
    t.tween_property(flare, "scale", Vector2.ONE, duration) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(flare, "modulate:a", 0.0, duration * 0.6) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t.tween_callback(flare.queue_free)


# The pile answers the catch: an expanding, fading ring of violet behind the button, twice.
# A child of the button (show_behind_parent) so it rides the catch punch; its own tween so
# it finishes and frees itself whatever this presenter does next.
func _spawn_pile_ring(pile: CardPileOpener) -> void:
    var ring := _make_light(RING_SIZE, LIGHT)
    ring.show_behind_parent = true
    ring.process_mode = Node.PROCESS_MODE_ALWAYS
    ring.modulate.a = 0.0
    pile.add_child(ring)
    ring.position = pile.size / 2.0 - ring.size / 2.0
    var t := ring.create_tween()
    for pulse in RING_PULSES:
        t.tween_callback(func() -> void:
            ring.scale = Vector2(0.45, 0.45)
            ring.modulate.a = 0.75
        )
        t.tween_property(ring, "scale", Vector2.ONE, RING_PERIOD) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        t.parallel().tween_property(ring, "modulate:a", 0.0, RING_PERIOD) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    t.tween_callback(ring.queue_free)


# tween_method driver for the exit streak: sheds a mote at the card's LIVE centre, throttled
# on a real-time clock (the streak accelerates, so a t-based gap would clump motes at the
# slow launch and leave the fast rush bare). `_t` is ignored on purpose.
func _trail_step(_t: float, ui: Control, state: Dictionary) -> void:
    var now := Time.get_ticks_msec()
    if now - int(state["last_ms"]) < MOTE_INTERVAL_MS:
        return
    state["last_ms"] = now
    if not is_instance_valid(ui):
        return
    _spawn_mote(ui.position + ui.pivot_offset, ui.scale.x)


func _spawn_mote(center: Vector2, card_scale: float) -> void:
    var color := LIGHT
    color.a = MOTE_ALPHA
    var mote := _make_light(randf_range(MOTE_SIZE_MIN, MOTE_SIZE_MAX), color)
    add_child(mote)
    # Scatter follows the card's shrinking scale: a fixed cloud around a 12%-scale card
    # reads as detached specks instead of a wake.
    var spread := MOTE_SCATTER * maxf(card_scale, 0.15)
    mote.position = center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread)) - mote.size / 2.0
    var t := mote.create_tween()
    t.tween_property(mote, "modulate:a", 0.0, MOTE_LIFETIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    t.parallel().tween_property(mote, "scale", Vector2(0.3, 0.3), MOTE_LIFETIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    t.parallel().tween_property(mote, "position", mote.position + Vector2(randf_range(-8.0, 8.0), randf_range(4.0, 14.0)), MOTE_LIFETIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.tween_callback(mote.queue_free)
