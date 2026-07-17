extends Camera2D

# Captured once at rest so punch_zoom() always animates relative to the TRUE resting
# zoom, even if a second big hit lands while an earlier punch hasn't fully eased back yet.
var _base_zoom: Vector2
var _zoom_tween: Tween

func _ready() -> void:
    _base_zoom = zoom

func shake(intensity: float, duration: float) -> void:
    var elapsed = 0.0
    var original_offset = offset

    while elapsed < duration:
        elapsed += get_process_delta_time()
        offset = original_offset + Vector2(
            randf_range(-intensity, intensity),
            randf_range(-intensity, intensity)
        )
        await get_tree().process_frame

    offset = original_offset

# Tiny zoom-in-then-back punch for big hits - animates `zoom` (unlike shake, which offsets
# `offset`), so the two can play together without fighting over the same property.
# `amount` is a fraction of the base zoom (e.g. 0.045 = zoom in ~4.5%).
func punch_zoom(amount: float, punch_in_duration: float = 0.08, return_duration: float = 0.22) -> void:
    if _zoom_tween and _zoom_tween.is_valid():
        _zoom_tween.kill()
    zoom = _base_zoom
    var punched_zoom := _base_zoom * (1.0 - amount)

    _zoom_tween = create_tween()
    _zoom_tween.tween_property(self, "zoom", punched_zoom, punch_in_duration) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _zoom_tween.tween_property(self, "zoom", _base_zoom, return_duration) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
