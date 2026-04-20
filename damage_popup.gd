extends Node2D
@onready var label: Label = $Label
var fade_duration: float = 0.6

func show_damage(amount: int) -> void:
    label.text = "-"+str(amount)
    var tween := create_tween()
    tween.tween_property(self, "position", position + Vector2.UP * 30, fade_duration)
    tween.parallel().tween_property(self, "modulate:a", 0.0, fade_duration)
    tween.finished.connect(queue_free)
