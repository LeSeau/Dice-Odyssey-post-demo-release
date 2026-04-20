extends Panel

@onready var vbox := $VBoxContainer
@onready var tooltip_label: RichTextLabel = %TooltipText

func show_tooltip(global_pos: Vector2) -> void:
    # Convert global to local relative to parent
    position = get_parent().get_canvas_transform().affine_inverse() * global_pos
    show()



func hide_tooltip() -> void:
    hide()

func get_tooltip_content(dice):
    var text := ""
    if dice == "evil":
        text = "Faces: 6, 6, 6, 0"
    elif dice == "giant":
        text = "Faces: 1-12"
    elif dice == "magma":
        text = "Faces: 1-6. Deals X damage to ALL enemies every roll."
    elif dice == "even":
        text = "Faces: 2, 4, 6, 8"
    elif dice == "odd":
        text = "Faces: 1, 3, 5, 7"
    elif dice == "blue":
        text = "Faces: 1-6"
    elif dice == "red":
        text = "Faces: 1-6"
    elif dice == "green":
        text = "Faces: 1-3"
    tooltip_label.text = text
