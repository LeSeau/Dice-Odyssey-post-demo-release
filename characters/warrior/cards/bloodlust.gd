extends Card

var disconnect_timer_started := false

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    Events.enemy_died.connect(_on_enemy_died)
    disconnect_timer_started = false
    
    var damage_effect := DamageEffect.new()
    damage_effect.sound = sound 
    var base_damage = Global.roll_value
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.execute(targets)
    
    # Start a simple timer using a different approach
    start_disconnect_timer()
    
    Events.dice_roll_reset.emit()
    Events.dice_amount_changed.emit()

func start_disconnect_timer() -> void:
    if disconnect_timer_started:
        return
    disconnect_timer_started = true
    
    # Use a simple loop instead of Timer node
    await_and_disconnect()

func await_and_disconnect() -> void:
    # Wait for 0.3 seconds using a simple counter
    for i in range(30):  # 30 frames at 60fps ≈ 0.5 seconds
        await Engine.get_main_loop().process_frame
    
    # Disconnect if still connected
    if Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.disconnect(_on_enemy_died)

func _on_enemy_died(enemy: Enemy) -> void:
    print("enemy died, bloodlust")
    
    # Disconnect immediately so we only charge once
    if Events.enemy_died.is_connected(_on_enemy_died):
        Events.enemy_died.disconnect(_on_enemy_died)
    
    var active_dice = Global.dice_type
    var dice_amount_variable = active_dice + "_dice_current_amount"

    
    if dice_amount_variable in Global:
        var current_amount = Global.get(dice_amount_variable)
        Global.set(dice_amount_variable, current_amount + 1)
        
        Events.change_current_power.emit()
        Events.charge_dice_animation.emit()
        Events.dice_amount_changed.emit()
