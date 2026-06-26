extends Button

const IDLE_PULSE_DURATION := 1.2
const IDLE_PULSE_MIN_GLOW := 0.85
const IDLE_PULSE_MAX_GLOW := 1.25

const HOVER_SCALE := Vector2(1.06, 1.06)
const PRESS_SCALE := Vector2(0.88, 0.88)
const RELEASE_OVERSHOOT_SCALE := Vector2(1.08, 1.08)
const REST_SCALE := Vector2(1.0, 1.0)

@onready var dice: Dice = $".."

var _scale_tween: Tween
var _idle_tween: Tween


func _ready() -> void:
    pivot_offset = size / 2
    button_down.connect(_on_button_down)
    button_up.connect(_on_button_up)
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    _start_idle_pulse()


# Gentle ambient brightness breathing so the main action of the game doesn't
# sit there looking dead between rolls. Drives modulate (not scale), since
# scale is already owned by the hover/press feedback below — keeping them on
# separate properties means they can never fight each other for control.
func _start_idle_pulse() -> void:
    _idle_tween = create_tween().set_loops()
    _idle_tween.tween_property(self, "modulate", Color(IDLE_PULSE_MAX_GLOW, IDLE_PULSE_MAX_GLOW, IDLE_PULSE_MAX_GLOW, 1.0), IDLE_PULSE_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _idle_tween.tween_property(self, "modulate", Color(IDLE_PULSE_MIN_GLOW, IDLE_PULSE_MIN_GLOW, IDLE_PULSE_MIN_GLOW, 1.0), IDLE_PULSE_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_scale(target: Vector2, duration: float, trans: Tween.TransitionType, ease: Tween.EaseType) -> Tween:
    if _scale_tween and _scale_tween.is_valid():
        _scale_tween.kill()
    _scale_tween = create_tween()
    _scale_tween.tween_property(self, "scale", target, duration).set_trans(trans).set_ease(ease)
    return _scale_tween


func _on_mouse_entered() -> void:
    _animate_scale(HOVER_SCALE, 0.1, Tween.TRANS_BACK, Tween.EASE_OUT)


func _on_mouse_exited() -> void:
    _animate_scale(REST_SCALE, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)


func _on_button_down() -> void:
    _animate_scale(PRESS_SCALE, 0.06, Tween.TRANS_EXPO, Tween.EASE_OUT)


func _on_button_up() -> void:
    var tween := _animate_scale(RELEASE_OVERSHOOT_SCALE, 0.08, Tween.TRANS_EXPO, Tween.EASE_OUT)
    tween.tween_property(self, "scale", REST_SCALE, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_pressed() -> void:
    print("roll pressed")
    dice.roll_dice()
