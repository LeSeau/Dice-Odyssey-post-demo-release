class_name ButtonFeel
extends RefCounted

# Shared button interaction feel (2026-08-15, STS2 audit 1.3 / 1.7).
#
# Our buttons had no motion at all: hover and press were pure stylebox swaps, which is
# why they read as flat next to painted art. The reference's buttons are painted, but the
# three things that actually make them feel good are paradigm-independent and work just as
# well on a StyleBoxFlat:
#
#   1. ASYMMETRIC HOVER TIMING - hover-in is near-instant, hover-out drifts back over ~0.5s
#      with an expo ease. Snap TO the hot state, drift back FROM it. This is the single best
#      find in that part of the audit: it reads as responsive without reading as twitchy,
#      and it costs nothing.
#   2. PRESS = MOVE THE BUTTON DOWN a few px. A physical displacement is a much stronger
#      "it depressed" signal than a colour swap, and it's the part players feel rather than
#      notice.
#   3. VISIBILITY CHANGE CLEARS HOVER STATE. A control that becomes invisible while hovered
#      never receives mouse_exited, so it comes back holding a stale hot state - the same
#      root cause as the "tooltip stays on screen forever" bug we have now fixed FOUR
#      separate times (intent, relic, battle reward, shop) with per-site patches.
#
# Deliberately NOT here: brightening via an HSV shader instead of `modulate`. That matters
# once a button is painted art (modulate multiplies, so it can only darken - pushing it past
# 1.0 blows toward white and flattens saturation, whereas scaling HSV's value channel
# brightens while preserving hue). On a flat stylebox rect there's no texture detail to
# preserve, so it buys nothing yet. It belongs with the painted-chrome batch.
#
# Usage: ButtonFeel.attach(some_button) once, typically in _ready().

const HOVER_IN_TIME := 0.0          # instant, on purpose
const HOVER_OUT_TIME := 0.5
const HOVER_LIFT := -2.0
const HOVER_BRIGHTEN := Color(1.18, 1.15, 1.12, 1.0)
const PRESS_DROP := 4.0
const PRESS_TIME := 0.06


static func attach(button: Button) -> void:
    if button == null or not is_instance_valid(button):
        return
    # Idempotent: attaching twice would double every tween.
    if button.has_meta("button_feel_attached"):
        return
    button.set_meta("button_feel_attached", true)

    # The exact bug we shipped on the dice-shop X button: `normal`/`hover` were overridden
    # to be transparent but `focus` and `pressed` were not, so those two fell back to the
    # project theme and appeared as a pale box the moment the button was clicked. Blanking
    # focus once, here, means no future button author has to remember it.
    if not button.has_theme_stylebox_override("focus"):
        button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

    var state := ButtonFeelState.new()
    state.button = button
    # Parented to the button so it dies with it - no manual cleanup, and no chance of a
    # tween writing into a freed control.
    button.set_meta("button_feel_state", state)

    button.mouse_entered.connect(state.on_hover_in)
    button.mouse_exited.connect(state.on_hover_out)
    button.button_down.connect(state.on_press)
    button.button_up.connect(state.on_release)
    button.visibility_changed.connect(state.on_visibility_changed)
    button.tree_exiting.connect(state.on_tree_exiting)


# Small state holder: each button needs its own rest position and its own tween, and the
# rest position can only be read once the button has been laid out.
class ButtonFeelState extends RefCounted:
    var button: Button
    var _rest_y: float
    var _rest_captured := false
    var _tween: Tween
    var _pressed := false
    var _hovered := false

    func _capture_rest() -> void:
        if _rest_captured or not is_instance_valid(button):
            return
        _rest_captured = true
        _rest_y = button.position.y

    func _retarget(offset_y: float, brighten: bool, duration: float,
            trans: Tween.TransitionType) -> void:
        if not is_instance_valid(button):
            return
        _capture_rest()
        if _tween and _tween.is_valid():
            _tween.kill()
        var target_color := ButtonFeel.HOVER_BRIGHTEN if brighten else Color.WHITE
        var target_y := _rest_y + offset_y
        if duration <= 0.0:
            button.position.y = target_y
            button.modulate = target_color
            return
        _tween = button.create_tween()
        _tween.set_parallel(true)
        _tween.tween_property(button, "position:y", target_y, duration) \
            .set_trans(trans).set_ease(Tween.EASE_OUT)
        _tween.tween_property(button, "modulate", target_color, duration) \
            .set_trans(trans).set_ease(Tween.EASE_OUT)

    func on_hover_in() -> void:
        if not is_instance_valid(button) or button.disabled:
            return
        _hovered = true
        _retarget(ButtonFeel.HOVER_LIFT, true, ButtonFeel.HOVER_IN_TIME, Tween.TRANS_LINEAR)

    func on_hover_out() -> void:
        _hovered = false
        _pressed = false
        # The slow drift home. EXPO ease-out means it leaves the hot state immediately and
        # then coasts, so it never looks like it's lagging behind the cursor.
        _retarget(0.0, false, ButtonFeel.HOVER_OUT_TIME, Tween.TRANS_EXPO)

    func on_press() -> void:
        if not is_instance_valid(button) or button.disabled:
            return
        _pressed = true
        _retarget(ButtonFeel.PRESS_DROP, true, ButtonFeel.PRESS_TIME, Tween.TRANS_QUAD)

    func on_release() -> void:
        if not _pressed:
            return
        _pressed = false
        # Back to hover height if the cursor is still on it, otherwise all the way home.
        if _hovered:
            _retarget(ButtonFeel.HOVER_LIFT, true, ButtonFeel.PRESS_TIME, Tween.TRANS_QUAD)
        else:
            _retarget(0.0, false, ButtonFeel.HOVER_OUT_TIME, Tween.TRANS_EXPO)

    func on_visibility_changed() -> void:
        # See the header note: a hidden control never gets mouse_exited, so without this it
        # comes back lifted and brightened forever.
        if is_instance_valid(button) and not button.is_visible_in_tree():
            _snap_home()

    func on_tree_exiting() -> void:
        if _tween and _tween.is_valid():
            _tween.kill()

    func _snap_home() -> void:
        if not is_instance_valid(button):
            return
        _hovered = false
        _pressed = false
        if _tween and _tween.is_valid():
            _tween.kill()
        if _rest_captured:
            button.position.y = _rest_y
        button.modulate = Color.WHITE
