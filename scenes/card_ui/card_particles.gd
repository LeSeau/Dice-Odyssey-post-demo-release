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
    # Steeper power slope specifically (low-power floor was landing right, so left that roughly
    # alone - Julien wants MORE at high power specifically). roll=1 -> 90, roll=12 -> 255,
    # exceeding the original's own ceiling (240 at roll 12) while the tight spread/hard damping/
    # short lifetime below keep even this much denser burst reading as a sharp impact rather
    # than the old diffuse floaty cloud.
    amount = 75 + 15 * roll_value
    initial_velocity_min = 260.0
    initial_velocity_max = 340.0 + float(roll_value) * 22.0
    damping_min = 340.0
    damping_max = 460.0

    # --- Spread: was 105.46 in the .tscn default (a ~210 degree cone, nearly omnidirectional)
    # - tightened into a real directional burst instead of an all-around puff.
    spread = 42.0

    # --- Size --- (bumped up a bit so the higher particle count above stays readable as
    # distinct chunks rather than blurring into noise)
    scale_amount_min = 2.5 + float(roll_value) * 0.1
    scale_amount_max = 4.8 + float(roll_value) * 0.18

    # --- Lifetime --- (was 0.6+0.04*roll -> 1.08s at roll 12, too long; a shorter-still-than-
    # this earlier revision cut it so much the burst vanished before its own density could
    # register - nudged the floor back up a bit)
    lifetime = 0.34 + float(roll_value) * 0.015

    # --- Gravity: pull them down so they arc nicely ---
    gravity = Vector2(0, 320)  # was 400/500 - damping now shares the "settle down fast" job

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
    await get_tree().create_timer(lifetime + 0.1).timeout
    queue_free()
