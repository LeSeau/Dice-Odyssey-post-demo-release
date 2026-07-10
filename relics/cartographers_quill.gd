extends Relic

# Passive - battle.gd::_on_scout_effect() reads Global.scout_bonus_amount directly
# and clamps to the panel's 5 hardcoded slots, same as the base Scout amount always was.
func initialize_relic(_owner: RelicUI) -> void:
    Global.scout_bonus_amount += 1

func deactivate_relic(_owner: RelicUI) -> void:
    Global.scout_bonus_amount = maxi(0, Global.scout_bonus_amount - 1)
