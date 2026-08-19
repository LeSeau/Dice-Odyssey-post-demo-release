extends Status

# Display-only badge for Counterfeit. The rule itself lives in Global.face_overrides (cleared
# by battle.gd::start_battle), so before this badge existed the card silently changed a die's
# faces for the whole combat with nothing on screen to say so (Julien, 2026-08-19).
# Same badge/effect split as Emanation and Trebuchet.
#
# Deliberately no class_name: nothing references this type by class, and skipping it avoids
# the editor class-cache restart dance.


func apply_status(_target: Node) -> void:
	status_applied.emit(self)
