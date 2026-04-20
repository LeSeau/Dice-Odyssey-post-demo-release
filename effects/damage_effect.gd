class_name DamageEffect
extends Effect

var amount := 0
var receiver_modifier_type := Modifier.Type.DMG_TAKEN
const DAMAGE_POPUP_SCENE := preload("res://scenes/ui/damage_popup.tscn")  # or wherever your popup scene is



func execute(targets: Array[Node]) -> void:
    for target in targets:
        if not target or not is_instance_valid(target):
            continue
        if target is Enemy or target is Player:
            target.take_damage(amount, receiver_modifier_type )
            
            # Create the damage popup
            var damage_popup = DAMAGE_POPUP_SCENE.instantiate()
            # Add it to the scene tree - you might want to add it to a UI layer instead of directly to the target
            target.get_parent().add_child(damage_popup)
            
            # Position the popup at the target's position
            damage_popup.global_position = target.global_position
            
            # Show the damage using your existing method
            # Set fade duration
            damage_popup.fade_duration = 1.2  # Longer fade time
            damage_popup.show_damage(Global.damage_to_display)
            
            SFXPlayer.play(sound)
