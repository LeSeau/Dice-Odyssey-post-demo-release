extends CanvasLayer

# Screen-transition curtain (autoload "Curtain").
#
# Every screen change in the run used to be a hard cut: _change_view() frees the old view
# and adds the new one in the same frame, and change_scene_to_* swaps the whole tree. This
# fades a flat plate over the swap instead - cover(), swap, reveal().
#
# Built entirely in code (no .tscn, no class_name) - same convention as run_stats_panel.gd,
# achievement_toast.gd and card_inspect_overlay.gd. Nothing to import, nothing for a live
# editor to re-save, and registering it is one line in project.godot.
#
# LAYER: 110, above everything the game draws - TopBar (3), the pause menu (60), the
# achievement toast (90), card inspect (99), tooltips and the Discord pin (100). A curtain
# that something can draw on top of is not a curtain.
#
# PAUSE: process_mode = ALWAYS, because two of the covered moments happen with the tree
# already paused (quitting from the pause menu, and from the Game Over panel).
#
# TIME: the fade is driven by _process against Time.get_ticks_msec(), NOT by a Tween, for
# two reasons. (1) Tween.set_ignore_time_scale() does not exist in Godot 4.3 (the trap that
# bit the hit-stop rework), so a tween fade would be stretched ~10x by a hit-stop still
# running when the curtain starts - and dying to a big hit is exactly such a moment.
# (2) Awaiting a tween's finished signal deadlocks if anything kills that tween mid-fade,
# and the callers await cover() before entering a room - a hang there is a soft-lock.
# Callers wait on that same real-time fade rather than on a parallel timer of equal
# length - see _await_fade for why a second clock was not good enough.

# Flat navy plate rather than pure black: it is the same colour as the event/end-screen
# panels, so the wipe reads as the game's own veil instead of a loading screen. Swap this
# one constant for Color(0, 0, 0) if a true blackout is wanted.
const CURTAIN_COLOR := Color(0.08, 0.102, 0.16)

# Asymmetric on purpose: leaving is quick, arriving is unhurried. Together they add under
# half a second to a screen change; much slower starts to read as a load.
#
# The plate fades UNIFORMLY, and that is a decision, not an omission. A radial wipe was tried
# and dropped (2026-09-12): tight enough to read as a curtain it is an iris, and the centre
# was clear at 63ms of a 320ms reveal while the corners - where gold, HP and End Turn live -
# stayed dark to the end. Softened until it stopped reading as an iris it was invisible, and
# still cost perceived speed, because a front the eye can track makes a transition feel
# longer than a uniform dip of the same length. Reach for REVEAL_TIME, not for a shape.
const COVER_TIME := 0.18
const REVEAL_TIME := 0.26

# Backstop only - see _await_fade. Generous on purpose: it must never cut a legitimate
# fade short, only rescue a screen that would otherwise stay black forever.
const FADE_TIMEOUT_MS := 2000

var _rect: ColorRect
var _from_alpha := 0.0
var _to_alpha := 0.0
var _ease := Tween.EASE_IN
var _duration := 0.0
var _start_ms := 0
var _fading := false


func _ready() -> void:
    layer = 110
    process_mode = Node.PROCESS_MODE_ALWAYS

    _rect = ColorRect.new()
    _rect.color = Color(CURTAIN_COLOR, 0.0)
    _rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    # STOP while it is up: a covered screen must not accept clicks meant for whatever is
    # being swapped underneath. It is hidden outright once revealed (see _finish), so it
    # can never eat input while the player can see through it.
    _rect.mouse_filter = Control.MOUSE_FILTER_STOP
    _rect.visible = false
    add_child(_rect)
    set_process(false)


# Fade to opaque, then return. Safe to await. Returns immediately if the screen is already
# covered, so a cover that happens during boot (when the menu's own cover is still up)
# costs nothing instead of adding a pointless second wait.
func cover(duration := COVER_TIME) -> void:
    if is_covered():
        return
    _begin(1.0, duration, Tween.EASE_IN)
    await _await_fade()


# Fade back to transparent. Callers generally do NOT await this - the new screen is already
# up and can start playing its own entrance underneath the fade.
func reveal(duration := REVEAL_TIME) -> void:
    if not _rect.visible and is_equal_approx(_rect.color.a, 0.0):
        return
    # One frame at full cover before the wipe opens. Callers reveal the moment the new
    # screen is added, and Godot's containers lay out on a DEFERRED sort - so the relic
    # bar, the hand and the dice row would otherwise settle on the first visible frame,
    # a micro-jump seen through the fade. Costs ~16ms; emitted while paused too.
    await get_tree().process_frame
    _begin(0.0, duration, Tween.EASE_OUT)
    await _await_fade()


# The caller waits on the SAME clock that drives the plate, rather than on a parallel
# SceneTreeTimer of equal length. Measured: a timer can fire well before the fade finishes
# when a frame takes an unusually long time (loading a battle scene is exactly that), and
# the caller would then swap the screen while the plate is still see-through - the visible
# cut this whole thing exists to remove.
#
# process_frame is emitted every main-loop iteration, pause included, so this cannot stall
# on a paused tree. The deadline is a pure backstop: _fading is cleared by _process off the
# wall clock, so the only way to still be here is something having disabled processing on
# this node, and a stuck black screen would be a soft-lock.
func _await_fade() -> void:
    var deadline := Time.get_ticks_msec() + FADE_TIMEOUT_MS
    while _fading and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame


func is_covered() -> bool:
    return _rect.visible and is_equal_approx(_rect.color.a, 1.0) and not _fading


func _begin(target_alpha: float, duration: float, ease_type: Tween.EaseType) -> void:
    _rect.visible = true
    if duration <= 0.0:
        _rect.color.a = target_alpha
        _finish()
        return
    _from_alpha = _rect.color.a
    _to_alpha = target_alpha
    _duration = duration
    _ease = ease_type
    # The clock starts on the first PROCESSED frame, not here. reveal() is called right
    # after a new screen is added, and the frame that follows is the first one to DRAW it
    # (texture uploads, shader compiles) - often the slowest frame of the whole change.
    # Anchored here, that frame's cost would be counted as fade time and the first visible
    # step would already be a third open: the screen pops through the plate instead of
    # fading in. Anchored on the first tick, the fade always starts from fully closed.
    _start_ms = -1
    _fading = true
    set_process(true)


func _process(_delta: float) -> void:
    if _start_ms < 0:
        _start_ms = Time.get_ticks_msec()
    var elapsed := float(Time.get_ticks_msec() - _start_ms) / 1000.0
    if elapsed >= _duration:
        _rect.color.a = _to_alpha
        _finish()
        return
    # Tween.interpolate_value as a static curve helper, the same way the hit-stop ramp uses
    # it - the easing is wanted, the Tween object's own clock is not.
    _rect.color.a = Tween.interpolate_value(
        _from_alpha, _to_alpha - _from_alpha, elapsed, _duration, Tween.TRANS_SINE, _ease
    )


func _finish() -> void:
    _fading = false
    set_process(false)
    # Fully transparent means fully out of the way: hidden, so it cannot intercept a click
    # even if some future caller forgets to reveal.
    _rect.visible = _rect.color.a > 0.0
