extends Status

# Display-only badge for Kaleidoscope. The rule lives in Global.keep_power_on_type_change,
# cleared by player_handler.start_turn() - this badge is the only thing telling the player the
# rule is currently ON (Julien, 2026-08-19).
#
# EVENT_BASED, so StatusHandler.apply_statuses_by_type skips it and nothing decrements our
# duration: expiring is this status's own job, exactly like RupturedStatus. Setting
# duration = 0 makes StatusUI free the badge (that branch needs can_expire = true in the
# .tres). The clear happens on the same signal the flag itself is cleared on, so the badge
# and the rule can never disagree.
#
# No class_name on purpose (see status_counterfeit.gd).


func initialize_status(_target: Node) -> void:
	if not Events.player_turn_started.is_connected(_on_player_turn_started):
		Events.player_turn_started.connect(_on_player_turn_started)


func apply_status(_target: Node) -> void:
	status_applied.emit(self)


func _on_player_turn_started() -> void:
	duration = 0
	if Events.player_turn_started.is_connected(_on_player_turn_started):
		Events.player_turn_started.disconnect(_on_player_turn_started)
