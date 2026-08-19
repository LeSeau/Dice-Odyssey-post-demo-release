extends Status

# Display-only badge for Red Edge - same gap and same fix as Counterfeit: the real effect is
# the fight-scoped Global.face_overrides["red"] trim, which was invisible until now.
# No class_name on purpose (see status_counterfeit.gd).


func apply_status(_target: Node) -> void:
	status_applied.emit(self)
