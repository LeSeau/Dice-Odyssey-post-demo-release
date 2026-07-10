extends Relic

# Passive - every Blessing card's roll-threshold gate is written inline as
# `if Global.roll_value >= N or Global.blessing_cast_any_roll:` (see the 2026-07-10
# session pass across all Blessing scripts), so this just flips that shared flag.
func initialize_relic(_owner: RelicUI) -> void:
    Global.blessing_cast_any_roll = true

func deactivate_relic(_owner: RelicUI) -> void:
    Global.blessing_cast_any_roll = false
