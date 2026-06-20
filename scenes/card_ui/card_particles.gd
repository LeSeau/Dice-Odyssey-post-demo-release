extends CPUParticles2D

func play_effect(roll_value: int, dice_type: String) -> void:
    match dice_type:
        "magma":  color = Color("ff3300f0")
        "blue":   color = Color("3c6ff1e4")
        "red":    color = Color("cc2200ff")
        "green":  color = Color("00ee79ff")
        "odd":    color = Color("ecc30bff")
        "even":   color = Color("ff994dff")
        "evil":   color = Color("cc33b2ff")
        "giant":  color = Color("88ff44f0")
        "mech":   color = Color("888888ff")
        _:        color = Color(1, 1, 1, 1)

    # --- Quantity & velocity ---
    amount = 60 + 15 * roll_value
    initial_velocity_min = 160.0
    initial_velocity_max = 250.0 + float(roll_value) * 35.0

    # --- Size ---
    scale_amount_min = 2.0 + float(roll_value) * 0.12
    scale_amount_max = 4.0 + float(roll_value) * 0.25

    # --- Lifetime ---
    lifetime = 0.6 + float(roll_value) * 0.04
    
    # --- Gravity: pull them down so they arc nicely ---
    gravity = Vector2(0, 400)                            # was 500, softer arc

    # --- Hue variation: slight shift for energy feel ---
    hue_variation_min = -0.05
    hue_variation_max = 0.05

    # --- Color ramp: fade to transparent ---
    var gradient := Gradient.new()
    gradient.add_point(0.0, color)
    gradient.add_point(0.6, Color(color.r, color.g, color.b, 0.6))
    gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
    color_ramp = gradient

    emitting = true
    await get_tree().create_timer(lifetime + 0.2).timeout
    queue_free()
