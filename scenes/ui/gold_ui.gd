class_name GoldUI
extends HBoxContainer

@export var run_stats: RunStats : set = set_run_stats

@onready var label: Label = $Label

const COUNT_DURATION := 0.6

var _displayed_gold: int = 0
var _count_tween: Tween

func _ready() -> void:
    label.text = "0"

func set_run_stats(new_value: RunStats) -> void:
    run_stats = new_value

    if not Events.gold_changed.is_connected(_update_gold):
        Events.gold_changed.connect(_update_gold)
        _displayed_gold = Global.gold
        label.text = str(_displayed_gold)
        Events.check_if_can_purchase_dice.emit()

# Counts the label up (or down) to the new balance instead of snapping straight to it, so a
# fight/event payout reads as "gold coming in" rather than the number just changing. Any
# in-progress count gets killed and restarted from wherever it currently is, so rapid back-to-
# back gold changes chain smoothly instead of jumping. check_if_can_purchase_dice is emitted
# once the count settles (not immediately) so the affordability badge lines up with what the
# player actually sees on screen, not the underlying value a moment early.
func _update_gold() -> void:
    var target: int = Global.gold
    if _count_tween and _count_tween.is_valid():
        _count_tween.kill()

    if target == _displayed_gold:
        Events.check_if_can_purchase_dice.emit()
        return

    _count_tween = create_tween()
    _count_tween.tween_method(_set_displayed_gold, _displayed_gold, target, COUNT_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _count_tween.finished.connect(func(): Events.check_if_can_purchase_dice.emit())


func _set_displayed_gold(value: int) -> void:
    _displayed_gold = value
    label.text = str(value)
