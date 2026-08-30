extends Node

# Harness for the 2026-08-29 scout summon (card -> comet -> seam -> unfurl -> existing reveal).
#
#   "<godot>" --path . res://debug_scout_summon.tscn --rendering-driver opengl3 --position 2000,2000
#   SCOUT_MOVIE=1 "<godot>" --path . res://debug_scout_summon.tscn --write-movie scout_frames/f.png \
#       --fixed-fps 30 --resolution 1280x720
#
# Everything is sampled in GAME TIME (SceneTreeTimer), never in frame counts: headless/movie runs
# advance frames at a completely different rate than play, and an earlier harness in this project
# measured an anticipation beat believing it had measured the punch because of exactly that.

const FIGHT := "res://battles/tier_0_machopeur.tres"
const CARD_RELEASE := Vector2(470.0, 470.0)  # a plausible drop point, low-centre like a real play

var _fails: Array[String] = []
var _checks := 0
var _battle: Node = null


func _ready() -> void:
    var music := AudioServer.get_bus_index("Music")
    if music >= 0:
        AudioServer.set_bus_mute(music, true)
    # Silences the achievement toasts that would otherwise fire on a scripted fight.
    Global.tutorial_on = true

    _battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
    _battle.battle_stats = load(FIGHT)  # the .tres, NEVER the .tscn - a PackedScene here kills _ready silently
    add_child(_battle)
    await _settle(1.2)

    if OS.get_environment("SCOUT_MOVIE") == "1":
        await _movie()
    else:
        await _section_a_timing()
        await _section_b_single_comet()
        await _section_c_origins()
        await _section_d_no_stranded_fx()
        await _section_e_tutorial_faces()
        await _section_f_self_clearing()
        _report()
    get_tree().quit()


# --- A. the panel is summoned, not snapped in -------------------------------------------------
func _section_a_timing() -> void:
    print("\n[A] summon timing")
    _cast_scout(3)

    await _settle(0.15)
    _check("A1 panel still hidden while the comet flies", not _panel().visible)
    _check("A2 a comet exists during the flight", _fx_count() > 0)

    await _settle(0.35)  # ~0.5s in: impact has happened, unfurl in progress or just done
    _check("A3 panel visible after impact", _panel().visible)

    await _settle(0.45)
    var s: Vector2 = _panel().scale
    _check("A4 unfurl finished at full scale (got %s)" % str(s),
            absf(s.x - 1.0) < 0.01 and absf(s.y - 1.0) < 0.01)
    _check("A5 pivot handed back to bottom-centre for the close fold (got %.1f, want %.1f)"
            % [_panel().pivot_offset.y, _panel().size.y],
            absf(_panel().pivot_offset.y - _panel().size.y) < 0.5)

    await _settle(0.9)
    var lit := 0
    for f in _battle.scout_faces:
        if f.visible and f.modulate.a > 0.9 and f.mouse_filter != Control.MOUSE_FILTER_IGNORE:
            lit += 1
    _check("A6 all 3 faces revealed and clickable by ~1.9s (got %d)" % lit, lit == 3)

    _close()
    await _settle(0.5)


# --- B. one comet per scout, and a re-scout mid-flight doesn't stack ---------------------------
func _section_b_single_comet() -> void:
    print("\n[B] re-scout mid-flight")
    _cast_scout(3)
    await _settle(0.12)
    var first := _fx_count()
    _cast_scout(3)  # second scout while the first comet is still travelling
    await _settle(0.05)
    _check("B1 first scout spawned FX (got %d)" % first, first > 0)
    _check("B2 re-scout did not stack FX sets (got %d, want <= %d)" % [_fx_count(), first + 2],
            _fx_count() <= first + 2)
    await _settle(1.4)
    _check("B3 exactly one panel, fully open, after both", _panel().visible and absf(_panel().scale.y - 1.0) < 0.01)
    _close()
    await _settle(0.5)


# --- C. origin fallbacks ----------------------------------------------------------------------
func _section_c_origins() -> void:
    print("\n[C] origins")
    # No card this frame -> the die is the origin, so the flight still happens.
    Global.last_played_card_position = Vector2.ZERO
    Global.playing_red_card = false
    _battle._last_card_played_frame = -1
    _battle._on_scout_effect(3)
    await _settle(0.15)
    _check("C1 relic/status-cast scout still flies (from the die)", not _panel().visible)
    await _settle(1.2)
    _check("C2 ...and still opens", _panel().visible)
    _close()
    await _settle(0.5)

    # Released essentially on top of the panel -> the flight would be a twitch, so skip it.
    _cast_scout(3, _battle._scout_panel_center() + Vector2(10.0, 6.0))
    await _settle(0.06)
    _check("C3 release next to the panel opens immediately", _panel().visible)
    await _settle(1.6)
    _close()
    await _settle(0.5)


# --- D. the leak this pass hardens ------------------------------------------------------------
func _section_d_no_stranded_fx() -> void:
    print("\n[D] no stranded FX")
    Global.next_guaranteed_roll = -1
    _cast_scout(3)
    await _settle(0.8)              # comfortably inside the mote flight, before any face commits
    var during := _fx_count()
    # Poll rather than guess: the first face commits ~1.13s after the cast, and an earlier version
    # of this harness sampled at 1.10s and "found no clickable face" - a harness bug that read
    # exactly like a broken pick.
    var clickable := await _await_clickable_face()
    _check("D1 FX were live mid-reveal (got %d)" % during, during > 0)
    _check("D2 a face became clickable", clickable != null)
    if clickable:
        var ev := InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = true
        _battle._on_scout_dice_clicked(ev, clickable)
    await _settle(0.9)
    _check("D3 nothing stranded after the pick (got %d)" % _fx_count(), _fx_count() == 0)
    _check("D4 the pick still delivered the guarantee", Global.next_guaranteed_roll != -1)
    await _settle(0.6)


func _await_clickable_face() -> Control:
    for i in 60:  # ~3s of game time
        for f in _battle.scout_faces:
            if f.visible and f.mouse_filter != Control.MOUSE_FILTER_IGNORE:
                return f
        await _settle(0.05)
    return null


# --- E. tutorial forcing survives the delayed open --------------------------------------------
func _section_e_tutorial_faces() -> void:
    print("\n[E] forced faces")
    Global.next_guaranteed_roll = -1
    Global.tutorial_forced_scout_faces = [4, 3, 5]
    _cast_scout(3)
    await _settle(1.9)
    var got: Array[int] = []
    for f in _battle.scout_faces:
        if f.visible and f.texture:
            var m := RegEx.new()
            m.compile(r"(\d+)\.png$")
            var r := m.search(f.texture.resource_path)
            if r:
                got.append(int(r.get_string(1)))
    _check("E1 forced faces consumed on the delayed open (got %s)" % str(got), got == [4, 3, 5])
    _close()
    await _settle(0.4)


# --- F. the summon cleans up after ITSELF, with no pick and no close ---------------------------
# THE GAP THAT LET A PARKED COMET SHIP. Section D only ever counted FX *after* a pick, and a pick
# runs _kill_scout_tweens, which frees everything by hand - so a node that never freed ITSELF was
# invisible to it. The comet had no queue_free callback at all and sat at the panel centre at full
# brightness until the next kill; Julien caught it in play as "a halo inside the middle dice".
func _section_f_self_clearing() -> void:
    print("\n[F] summon FX self-clear (no pick, no close)")
    Global.next_guaranteed_roll = -1
    _cast_scout(3)
    await _settle(2.6)  # flight + unfurl + all three reveals, with room to spare
    _check("F1 panel still open", _panel().visible)
    _check("F2 every summon FX freed itself (got %d still live)" % _fx_count(), _fx_count() == 0)
    _close()
    await _settle(0.5)


# --- movie mode -------------------------------------------------------------------------------
func _movie() -> void:
    await _settle(0.4)
    _cast_scout(3)
    await _settle(2.4)
    _pick_first_face()
    await _settle(1.4)


# --- helpers ----------------------------------------------------------------------------------
# Mimics a real card play: CardUI.play() stamps the release point and Card.play() emits
# card_played on its first line, then runs apply_effects() (which emits scout_effect) in the SAME
# frame. battle.gd's origin rule keys off exactly that same-frame relationship.
func _cast_scout(amount: int, release: Vector2 = CARD_RELEASE) -> void:
    Global.playing_red_card = false
    Global.last_played_card_position = release
    _battle._last_card_played_frame = Engine.get_process_frames()
    _battle._on_scout_effect(amount)


func _panel() -> Panel:
    return _battle.get_node("ScoutPanel") as Panel


func _fx_count() -> int:
    var n := 0
    for node in _battle._scout_fx_nodes:
        if is_instance_valid(node):
            n += 1
    return n


func _pick_first_face() -> void:
    for f in _battle.scout_faces:
        if f.visible and f.mouse_filter != Control.MOUSE_FILTER_IGNORE:
            var ev := InputEventMouseButton.new()
            ev.button_index = MOUSE_BUTTON_LEFT
            ev.pressed = true
            _battle._on_scout_dice_clicked(ev, f)
            return
    _fail("could not find a clickable face to pick")


func _close() -> void:
    _battle._close_scout_panel()


func _settle(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout


func _check(label: String, ok: bool) -> void:
    _checks += 1
    if ok:
        print("  PASS  %s" % label)
    else:
        _fail(label)


func _fail(label: String) -> void:
    _fails.append(label)
    print("  FAIL  %s" % label)


func _report() -> void:
    print("\n=== scout summon: %d checks, %d fail ===" % [_checks, _fails.size()])
    for f in _fails:
        print("  - %s" % f)
