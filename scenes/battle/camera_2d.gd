extends Camera2D

# Captured once at rest so punch_zoom() always animates relative to the TRUE resting
# zoom, even if a second big hit lands while an earlier punch hasn't fully eased back yet.
var _base_zoom: Vector2
var _zoom_tween: Tween

func _ready() -> void:
    _base_zoom = zoom

# Screen shake with a rise-and-fall envelope (2026-08-15, STS2 audit 4.3).
#
# Was: uniform random jitter at constant amplitude for the whole duration, ending in a
# hard snap back to the resting offset. Constant-amplitude-then-stop is what reads as a
# rattle (or a glitch); a recoil peaks early and dies away. The envelope below rises fast
# (the impact) and decays slowly (the settle), so the same peak amplitude reads as a much
# heavier hit while ending on a whisper instead of a cut.
#
# Kept as a coroutine on process_frame rather than a tween because overlapping shakes
# from AoE hits should be able to run without fighting each other over `offset`; each
# shake owns a generation token so only the newest one is allowed to write.
var _shake_generation := 0

func shake(intensity: float, duration: float) -> void:
    if duration <= 0.0:
        return
    _shake_generation += 1
    var my_generation := _shake_generation
    var original_offset := offset
    var elapsed := 0.0

    while elapsed < duration:
        # A newer shake took over - stop writing, and let IT own the restore.
        if my_generation != _shake_generation:
            return
        elapsed += get_process_delta_time()
        var t := clampf(elapsed / duration, 0.0, 1.0)
        # Fast attack, slow decay: full amplitude by ~15% in, then eased down to 0.
        var envelope := t / 0.15 if t < 0.15 else pow(1.0 - (t - 0.15) / 0.85, 2.0)
        var amplitude := intensity * envelope
        offset = original_offset + Vector2(
            randf_range(-amplitude, amplitude),
            randf_range(-amplitude, amplitude)
        )
        await get_tree().process_frame

    if my_generation == _shake_generation:
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
