extends Camera2D

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
