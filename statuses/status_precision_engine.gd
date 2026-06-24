class_name PrecisionEngineStatus
extends Status

func initialize_status(target: Node) -> void:
    if not Events.card_type_played.is_connected(_on_card_type_played):
        Events.card_type_played.connect(_on_card_type_played.bind(target))

func _on_card_type_played(card_type: String, target: Node) -> void:
    if card_type == "exact":
        var active_dice = Global.dice_type
        var dice_amount_variable = active_dice + "_dice_current_amount"
        if dice_amount_variable in Global:
            Global.set(dice_amount_variable, Global.get(dice_amount_variable) + 1)
            Events.dice_amount_changed.emit()
            Events.charge_dice_animation.emit()

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
