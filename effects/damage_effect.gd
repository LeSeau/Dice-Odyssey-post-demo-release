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
            target.take_damage(amount, receiver_modifier_type)
            
            var camera = target.get_tree().get_first_node_in_group("camera")
            if camera:
                camera.shake(amount * 0.3, 0.15)
            
            var damage_popup = DAMAGE_POPUP_SCENE.instantiate()
            target.get_parent().add_child(damage_popup)
            damage_popup.global_position = target.global_position
            damage_popup.fade_duration = 1.2
            damage_popup.show_damage(Global.damage_to_display)
            
            SFXPlayer.play(sound)
