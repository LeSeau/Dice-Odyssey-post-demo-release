class_name StatusUI
extends Control

@export var status: Status : set = set_status

@onready var icon: TextureRect = $Icon
@onready var duration: Label = $Duration
@onready var stacks: Label = $Stacks

const TooltipScene = preload("res://scenes/ui/status_tooltip.tscn")


func set_status(new_status: Status) -> void:
    if not is_node_ready():
        await ready
    status = new_status
    icon.texture = status.icon
    duration.visible = status.stack_type == Status.StackType.DURATION
    # Stacks visibility (including the hide_counter_when_zero check) is computed in
    # _on_status_changed(), called right below - single source of truth so it stays
    # correct as `stacks` changes over the status's lifetime, not just at creation.
    # Always the icon's own footprint, regardless of whether a Duration/Stacks badge is
    # showing - the badge overlays the icon corner, it shouldn't inflate the grid cell.
    # It used to grow to fit the label (48x39 vs 30x30), which made GridContainer give
    # numbered and un-numbered statuses different cell sizes in the same row - inconsistent
    # spacing between icons depending on which statuses happened to land next to each other.
    custom_minimum_size = icon.size

    if not status.status_changed.is_connected(_on_status_changed):
        status.status_changed.connect(_on_status_changed)

    _on_status_changed()
    
func _on_status_changed() -> void:
    if not status:
        return
    
    if status.can_expire and status.duration <= 0 :
        queue_free()
    if status.stack_type == Status.StackType.INTENSITY and status.stacks == 0 and status.can_expire:
        queue_free()
    
    duration.text = str(status.duration)
    stacks.text = str(status.stacks)
    stacks.visible = status.stack_type == Status.StackType.INTENSITY \
        and not (status.hide_counter_when_zero and status.stacks == 0)
    visible = not (status.hide_when_zero and status.stacks == 0)


var tooltip_instance_requirement: CanvasLayer
var tooltip_instance_bonus: Panel


func _on_icon_mouse_entered() -> void:
    if not status:
        return

    var status_pos = icon.global_position + Vector2(0, icon.size.y + 5)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)

    var tooltip_panel = tooltip_instance_requirement.get_node("StatusTooltip")

    tooltip_panel.get_tooltip_content(status)
    tooltip_panel.show_tooltip(status_pos)


func _on_icon_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null
