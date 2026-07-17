class_name UnluckyStatus
extends Status

# Lucky just guarantees the highest possible roll for the next dice roll
# We assume this is consumed after one use

func initialize_status(_target: Node) -> void:
    # Connect only once to avoid duplicate calls
    if not Events.check_unlucky_status.is_connected(on_lucky_check):
        Events.check_unlucky_status.connect(on_lucky_check)

func on_lucky_check() -> void:
    # Only act if duration > 0
    if duration <= 0:
        return

    # Set next roll to the highest possible value of the current dice
    var dice_type = Global.dice_type
    var values = []

    match dice_type:
        "blue", "red":
            values = [1,2,3,4,5,6]
        "evil":
            values = [0,6,6,6]
        "giant":
            values = [1,2,3,4,5,6,7,8,9,10,11,12]
        "magma":
            values = [1,2,3,4,5,6]
        "even":
            values = [2,4,6,8]
        "odd":
            values = [1,3,5,7]
        "green":
            values = [1,2,3]
        "mech":
            values = [1,2,3,4,5,6]

    # Dice infusions that change the value set (Repented Evil -> [6,6,6], Bulky Giant ->
    # [7..12]) must be reflected here, or Lucky/Unlucky could guarantee a value the die can
    # no longer roll (find() would miss and fall back to a random roll in dice.gd).
    var override_values: Array = DiceInfusions.roll_values_override(dice_type)
    if not override_values.is_empty():
        values = override_values

    #if values.empty():
        #return

    # Pick the min value for the next roll
    Global.next_guaranteed_roll = values.min()
    duration -= 1

    # Emit status changed for UI update
    status_changed.emit()
