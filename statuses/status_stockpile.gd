class_name StockpileStatus
extends Status

# END_OF_TURN: fires while the outgoing turn's bank is still readable (the wipe +
# starting_power_next_turn consumption happen at the NEXT turn's start in dice.gd).
func apply_status(_target: Node) -> void:
    if Global.roll_value > 0:
        # max() so a bigger explicit carry (e.g. the unpooled Tension card) is
        # never clobbered down to the Stockpile cap.
        Global.starting_power_next_turn = maxi(Global.starting_power_next_turn, mini(Global.roll_value, 8))
    status_applied.emit(self)
