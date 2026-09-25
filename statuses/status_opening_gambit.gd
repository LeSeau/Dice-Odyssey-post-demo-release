class_name OpeningGambitStatus
extends Status

var triggered_this_turn := true

func initialize_status(_target: Node) -> void:
    triggered_this_turn = true
    if not Events.player_turn_started.is_connected(_on_turn_started):
        Events.player_turn_started.connect(_on_turn_started)
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)

func _on_turn_started() -> void:
    triggered_this_turn = false

func _on_dice_rolled(_dice_type, _roll_value) -> void:
    if not triggered_this_turn:
        triggered_this_turn = true
        # One extra copy of the roll per Dice Echo played (stacks = copies, see absorb_copy):
        # one = double, two = triple.
        Global.roll_value += Global.last_roll * maxi(stacks, 1)
        Events.change_current_power.emit()


func absorb_copy(other: Status) -> bool:
    stacks += other.stacks
    return true


func get_tooltip() -> String:
    var copies := maxi(stacks, 1)
    var how: String = "double" if copies == 1 else ("triple" if copies == 2 else "%d times" % (copies + 1))
    return "Your first Dice roll each turn counts %s towards your Power" % how

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
