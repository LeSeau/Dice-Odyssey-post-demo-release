extends GridContainer

@export var fixed_h_spacing: int = 20  # Set your desired spacing

func _ready():
    resized.connect(_update_spacing)
    child_entered_tree.connect(_update_spacing)
    child_exiting_tree.connect(_update_spacing)
    _update_spacing()

func _update_spacing(_node = null):
    # Always ensure we have the desired spacing
    add_theme_constant_override("h_separation", fixed_h_spacing)
    
    # Force layout update
    queue_sort()
