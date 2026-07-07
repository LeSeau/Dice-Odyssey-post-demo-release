class_name ForesightStatus
extends Status

var target: Node

func initialize_status(_target: Node) -> void:
    target = _target
    # Connection outlives the fight (Events is an autoload) - the
    # is_instance_valid(target) guard in the handler is what actually retires a
    # stale instance, same pattern as LuckySevensStatus.
    if not Events.scout_effect.is_connected(_on_scout_effect):
        Events.scout_effect.connect(_on_scout_effect)

func apply_status(_target: Node) -> void:
    status_applied.emit(self)

func _on_scout_effect(_amount) -> void:
    if not is_instance_valid(target):
        return
    var property_name := "%s_dice_current_amount" % Global.dice_type
    Global.set(property_name, Global.get(property_name) + 1)
    Events.dice_amount_changed.emit()
    Events.charge_dice_animation.emit()
    Events.temporary_dice_added.emit(Global.dice_type)
