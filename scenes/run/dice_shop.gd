extends TextureButton

const DICE_SHOP_SCENE = "res://scenes/shop/dice_shop.tscn"

const HOVER_MODULATE := Color(1.18, 1.18, 1.18)
const HOVER_DURATION := 0.12

const BLINK_MIN_ALPHA := 0.55
const BLINK_DURATION := 1.2

# Dimmed look while the shop can't be entered from the current view (battle/event/
# shop/dice-infusion - see run.gd's set_available() call sites, previously
# dice_shop.hide()/.show()). The icon now stays in its fixed top-bar slot at all
# times instead of disappearing, so ConsultMapButton/DeckButton/PauseButton never
# shift position depending on which screen is up.
const UNAVAILABLE_MODULATE := Color(0.55, 0.55, 0.55, 0.55)
const AVAILABILITY_TWEEN_DURATION := 0.15

var _hover_tween: Tween
var _blink_tween: Tween
var _availability_tween: Tween
var _tooltip: Node
var _available := true
var _wants_blink := false

func _on_pressed() -> void:
    print("open dice shop")


# See const comment above. Kills any in-flight hover/tooltip/blink state before
# dimming so nothing keeps animating on a now-inert icon; re-applies a pending
# blink request (see set_blinking) once the shop becomes reachable again.
func set_available(enabled: bool) -> void:
    if _available == enabled:
        return
    _available = enabled
    disabled = not enabled
    if not enabled:
        if is_instance_valid(_tooltip):
            _tooltip.queue_free()
            _tooltip = null
        if _hover_tween and _hover_tween.is_valid():
            _hover_tween.kill()
        if _blink_tween and _blink_tween.is_valid():
            _blink_tween.kill()
    if _availability_tween and _availability_tween.is_valid():
        _availability_tween.kill()
    var target := Color.WHITE if enabled else UNAVAILABLE_MODULATE
    _availability_tween = create_tween()
    _availability_tween.tween_property(self, "modulate", target, AVAILABILITY_TWEEN_DURATION)
    if enabled and _wants_blink:
        set_blinking(true)


# Slow attention pulse while the player can afford a die (see AffordableIndicator/
# run.gd::_on_check_if_can_purchase_dice, which is the sole caller). Guarded so repeated calls
# while already blinking (gold changes fire this often) don't restart the tween from scratch.
# Remembers the request via _wants_blink even while unavailable/dimmed, so it resumes
# automatically once set_available(true) fires instead of needing a re-check.
func set_blinking(enabled: bool) -> void:
    _wants_blink = enabled
    if not _available:
        return
    if enabled:
        if _blink_tween and _blink_tween.is_valid():
            return
        _blink_tween = create_tween().set_loops()
        _blink_tween.tween_property(self, "modulate:a", BLINK_MIN_ALPHA, BLINK_DURATION) \
            .set_trans(Tween.TRANS_SINE)
        _blink_tween.tween_property(self, "modulate:a", 1.0, BLINK_DURATION) \
            .set_trans(Tween.TRANS_SINE)
    else:
        if _blink_tween and _blink_tween.is_valid():
            _blink_tween.kill()
        modulate.a = 1.0


# No separate hover texture art exists for this button, so hover feedback is a quick
# brightness tween on modulate instead - same flat/punchy timing as the map room hover pop.
func _on_mouse_entered() -> void:
    if not _available:
        return
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "modulate", HOVER_MODULATE, HOVER_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    if is_instance_valid(_tooltip):
        _tooltip.queue_free()
    _tooltip = IconTooltip.spawn_below(self, "Dice Shop")


func _on_mouse_exited() -> void:
    if not _available:
        return
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "modulate", Color.WHITE, HOVER_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    if is_instance_valid(_tooltip):
        _tooltip.queue_free()
        _tooltip = null
