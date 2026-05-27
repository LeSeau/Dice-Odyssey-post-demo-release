extends Relic

var owner_ui: RelicUI

func initialize_relic(owner: RelicUI) -> void:
    owner_ui = owner
    Events.red_dice_rolled.connect(_on_red_dice_rolled)
    print("blood sword initialized")

func _on_red_dice_rolled() -> void:
    owner_ui.flash()

    Global.roll_value += 2

    Events.change_current_power.emit()

    print("Red dice boosted by 2!")

func deactivate_relic(owner: RelicUI) -> void:
    if Events.red_dice_rolled.is_connected(_on_red_dice_rolled):
        Events.red_dice_rolled.disconnect(_on_red_dice_rolled)
