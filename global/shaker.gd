extends Node

func shake(thing: Node2D, strength: float, duration: float = 0.2) -> void:
    if not is_instance_valid(thing):
        return

    var orig_pos := thing.position
    var shake_count := 10
    var tween := create_tween()
    
    for i in shake_count:
        if not is_instance_valid(thing):
            break  # Stop shaking if it's no longer valid

        var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
        var target := orig_pos + strength * shake_offset
        if i % 2 == 0:
            target = orig_pos

        tween.tween_property(thing, "position", target, duration / float(shake_count))
        strength *= 0.75

    tween.finished.connect(func():
        if is_instance_valid(thing):
            thing.position = orig_pos
    )


func hit_stop(duration: float = 0.05, time_scale: float = 0.02) -> void:
    # Confirmed 2026-07-01 via a loud diagnostic (duration=0.5, time_scale=0.02) that Julien
    # could clearly see - at the ORIGINAL defaults (0.05 duration, 0.05 time_scale) it was
    # imperceptible. time_scale (how HARD the freeze is, not just how long) was the bigger
    # factor for visibility, so the default here now matches the diagnostic's time_scale
    # rather than the original softer 0.05 - only duration comes back down from the extreme
    # 0.5s diagnostic value to something that won't feel laggy at gameplay pace (rolls happen
    # every few seconds; call sites still scale their own duration by damage/roll value).
    Engine.time_scale = time_scale
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0
