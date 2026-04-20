class_name StatsUI
extends HBoxContainer

@onready var block: HBoxContainer = $Block
@onready var block_label: Label = %BlockLabel
@onready var health: HBoxContainer = $Health
@onready var health_label: Label = %HealthLabel

@onready var health_bar: ProgressBar = %HealthBar

# In _ready()
func _ready() -> void:
    # Store the original size of the block container
    var block_size = block.get_minimum_size()
    
    # Create a custom size flag for the block container
    block.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    block.custom_minimum_size.x = block_size.x
    

# Then modify your update_stats
func update_stats(stats: Stats) -> void:
    
    block_label.text = str(stats.block)
    health_label.text = str(stats.health) + "/" + str(stats.max_health)
    health_bar.value = stats.health
    health_bar.max_value = stats.max_health
    
    # Only show/hide the contents, not the container itself
    for child in block.get_children():
        child.visible = stats.block > 0
    
    health.visible = stats.health > 0
