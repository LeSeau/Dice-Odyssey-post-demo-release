extends Status

# Display-only badge for the Trebuchet Blessing - the real effect is
# Global.thrown_dice_bonus_fight (read by Card._on_thrown_die_landed), same
# badge/effect split as Emanation. Deliberately no class_name: nothing references
# this type by class, and skipping it avoids the editor class-cache restart dance.


func apply_status(_target: Node) -> void:
    status_applied.emit(self)
