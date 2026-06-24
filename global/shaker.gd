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


func hit_stop(duration: float = 0.05, time_scale: float = 0.05) -> void:
    Engine.time_scale = time_scale
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0
