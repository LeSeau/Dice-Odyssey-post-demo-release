extends CPUParticles2D

func play_effect(roll_value: int, dice_type):
    # Set color based on dice type
    match dice_type:
        "magma":
            color = Color("570800f0") 
        "blue":
            color = Color("3c6ff1e4") 
        "red":
            color = Color("#8b1301")
        "green":
            color = Color("00ee79") 
        "odd":
            color = Color("ecc30b")  
        "even":
            color = Color("ff994d") 
        "evil":
            color = Color("cc33b2")  
        "giant":
            color = Color("276e1ef0")  
        _:
            color = Color(1, 1, 1)  # White default
    
    # Adjust intensity based on roll value
    amount = 60 + 20 * roll_value  # More particles for higher rolls
    initial_velocity_max = 150 + (roll_value * 20)  # Faster for higher rolls
    scale_amount_min = 1.0 + (roll_value * 0.2)  # Bigger for higher rolls
    scale_amount_max = 2.0 + (roll_value * 0.3)
    
    # Play the effect
    emitting = true
    
    # Auto-delete after lifetime
    await get_tree().create_timer(lifetime + 0.1).timeout
    queue_free()
