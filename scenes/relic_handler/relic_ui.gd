class_name RelicUI
extends Control

@export var relic: Relic : set = set_relic
@onready var icon: TextureRect = $Icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var counter: Label = $Counter

# Tooltip instance
var tooltip_instance: CanvasLayer
const TooltipScene = preload("res://scenes/ui/tooltip.tscn")

func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func set_relic(new_relic: Relic) -> void:
    if not is_node_ready():
        await ready
    
    relic = new_relic
    icon.texture = relic.icon
    
    # Setup counter if this relic needs one
    if relic.has_counter:
        counter.visible = true
        Events.card_played.connect(_on_card_played)
        Events.player_turn_started.connect(_on_player_turn_started)
        update_counter()
    else:
        counter.visible = false

func _on_card_played(_card: Card) -> void:
    update_counter()
    
func _on_player_turn_started() -> void:
    update_counter()

func update_counter() -> void:
    if relic and relic.has_counter:
        counter.text = str(Global.cards_played_this_turn)
        counter.visible = true

# Keep your existing functionality
func flash() -> void:
    animation_player.play("flash")

var _hover_id := 0  # increment this to invalidate old coroutines

func _on_mouse_entered() -> void:
    flash()
    
    # Free any existing tooltip
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
    
    # Invalidate any pending coroutine
    _hover_id += 1
    var my_id := _hover_id
    
    await get_tree().create_timer(0.5).timeout
    
    # If hover_id changed, a newer hover started — bail out
    if my_id != _hover_id:
        return
    if not get_global_rect().has_point(get_global_mouse_position()):
        return
    if relic:
        tooltip_instance = TooltipScene.instantiate()
        get_tree().root.add_child(tooltip_instance)
        
        var tooltip_panel = tooltip_instance.get_node("Tooltip")
        tooltip_panel.tooltip_title.text = "[color=gold][b]%s[/b][/color]" % relic.relic_name
        tooltip_panel.tooltip_label.text = relic.tooltip
        var pos = get_global_mouse_position() + Vector2(24, 24)
        tooltip_panel.show_tooltip(pos)
        
        get_tree().create_timer(6.0).timeout.connect(func():
            if tooltip_instance and is_instance_valid(tooltip_instance):
                tooltip_instance.queue_free()
                tooltip_instance = null
        )

func _on_mouse_exited() -> void:
    _hover_id += 1  # also invalidate on exit
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
