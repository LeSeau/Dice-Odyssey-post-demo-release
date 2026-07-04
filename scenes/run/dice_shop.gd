extends TextureButton

const DICE_SHOP_SCENE = "res://scenes/shop/dice_shop.tscn"

const HOVER_MODULATE := Color(1.18, 1.18, 1.18)
const HOVER_DURATION := 0.12

const BLINK_MIN_ALPHA := 0.55
const BLINK_DURATION := 1.2

var _hover_tween: Tween
var _blink_tween: Tween

func _on_pressed() -> void:
    print("open dice shop")


# Slow attention pulse while the player can afford a die (see AffordableIndicator/
# run.gd::_on_check_if_can_purchase_dice, which is the sole caller). Guarded so repeated calls
# while already blinking (gold changes fire this often) don't restart the tween from scratch.
func set_blinking(enabled: bool) -> void:
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
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "modulate", HOVER_MODULATE, HOVER_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
    if _hover_tween and _hover_tween.is_valid():
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "modulate", Color.WHITE, HOVER_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
