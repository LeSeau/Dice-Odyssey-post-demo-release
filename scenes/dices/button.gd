extends Button

@onready var dice: Dice = $".."

func _ready() -> void:
    pivot_offset = size / 2
    button_down.connect(_on_button_down)
    button_up.connect(_on_button_up)


func _on_button_down() -> void:
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _on_button_up() -> void:
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_pressed() -> void:
    print("roll pressed")
    dice.roll_dice()
