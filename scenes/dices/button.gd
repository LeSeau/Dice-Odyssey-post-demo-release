extends Button

const HOVER_SCALE := Vector2(1.06, 1.06)
const PRESS_SCALE := Vector2(0.88, 0.88)
const RELEASE_OVERSHOOT_SCALE := Vector2(1.08, 1.08)
const REST_SCALE := Vector2(1.0, 1.0)

const ACTIVE_MODULATE := Color(1, 1, 1, 1)
const DEPLETED_MODULATE := Color(0.5, 0.5, 0.5, 1.0)

@onready var dice: Dice = $".."

var _scale_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
    pivot_offset = size / 2
    button_down.connect(_on_button_down)
    button_up.connect(_on_button_up)
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)


# Dim the button toward "inactive" whenever the active dice type has no dice left, so it
# reads as not-rollable. Checked per-frame (rather than wired to each of roll/charge/
# type-change/turn-start) to stay correct regardless of signal ordering - it's a trivial
# read. modulate is left to the press-flash while that tween is running so they don't fight.
func _process(_delta: float) -> void:
    if not (_flash_tween and _flash_tween.is_valid()):
        modulate = DEPLETED_MODULATE if _is_depleted() else ACTIVE_MODULATE


func _is_depleted() -> bool:
    return int(Global.get(Global.dice_type + "_dice_current_amount")) <= 0


func _animate_scale(target: Vector2, duration: float, trans: Tween.TransitionType, ease: Tween.EaseType) -> Tween:
    if _scale_tween and _scale_tween.is_valid():
        _scale_tween.kill()
    _scale_tween = create_tween()
    _scale_tween.tween_property(self, "scale", target, duration).set_trans(trans).set_ease(ease)
    return _scale_tween


func _on_mouse_entered() -> void:
    if _is_depleted():
        return
    _animate_scale(HOVER_SCALE, 0.1, Tween.TRANS_BACK, Tween.EASE_OUT)


func _on_mouse_exited() -> void:
    _animate_scale(REST_SCALE, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)


func _on_button_down() -> void:
    _animate_scale(PRESS_SCALE, 0.06, Tween.TRANS_EXPO, Tween.EASE_OUT)
    _flash_press()


# Neutral white flash on press - independent of active dice color on purpose, so the
# button keeps its own identity instead of re-tinting per dice type. Skipped when the
# dice type is depleted (no roll will happen), so the button stays visibly inactive.
func _flash_press() -> void:
    if _is_depleted():
        return
    if _flash_tween and _flash_tween.is_valid():
        _flash_tween.kill()
    _flash_tween = create_tween()
    _flash_tween.tween_property(self, "modulate", Color(2.2, 2.2, 2.2, 1.0), 0.04) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    _flash_tween.tween_interval(0.03)
    _flash_tween.tween_property(self, "modulate", ACTIVE_MODULATE, 0.22) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _on_button_up() -> void:
    var tween := _animate_scale(RELEASE_OVERSHOOT_SCALE, 0.08, Tween.TRANS_EXPO, Tween.EASE_OUT)
    tween.tween_property(self, "scale", REST_SCALE, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_pressed() -> void:
    print("roll pressed")
    dice.roll_dice()
