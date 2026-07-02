class_name DamageEffect
extends Effect

var amount := 0
var receiver_modifier_type := Modifier.Type.DMG_TAKEN
const DAMAGE_POPUP_SCENE := preload("res://scenes/ui/damage_popup.tscn")  # or whereve



func execute(targets: Array[Node]) -> void:
    for target in targets:
        if not target or not is_instance_valid(target):
            continue
        if target is Enemy or target is Player:
            target.take_damage(amount, receiver_modifier_type)
            
            var camera = target.get_tree().get_first_node_in_group("camera")
            if camera:
                # Higher floor + steeper curve so bread-and-butter 6-8 dmg hits (previously
                # only ~3-4px, imperceptible) actually register, while big hits still cap out.
                camera.shake(clampf(amount * 0.7 + 2.5, 5.0, 18.0), 0.15)

            # Roughly doubled (was 0.02-0.08) now that hit_stop()'s time_scale default is a
            # harder freeze - the old duration was tuned for the old, softer time_scale and
            # was imperceptible either way.
            Shaker.hit_stop(clampf(amount * 0.008, 0.04, 0.16))
            
            var damage_popup = DAMAGE_POPUP_SCENE.instantiate()
            target.get_parent().add_child(damage_popup)
            damage_popup.global_position = target.global_position
            damage_popup.fade_duration = 1.0
            var dealing_dice_type: String = Global.dice_type if target is Enemy else ""
            damage_popup.show_damage(Global.damage_to_display, dealing_dice_type)
            
            SFXPlayer.play(sound)
