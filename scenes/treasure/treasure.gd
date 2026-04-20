class_name Treasure
extends Control
@export var treasure_relic_pool: RelicPool  # Changed from Array[Relic] to RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats
@onready var animation_player: AnimationPlayer = %AnimationPlayer





var found_relic: Relic

func generate_relic() -> void:
    if not treasure_relic_pool:
        push_error("No relic pool assigned!")
        return

    # Get a relic from the pool, same way your event does
    found_relic = treasure_relic_pool.get_random_relic(char_stats, relic_handler)

    
func _on_treasure_opened() -> void:
    Events.treasure_room_exited.emit(found_relic)


func _on_treasure_chest_gui_input(event: InputEvent) -> void:
    if animation_player.current_animation == "open":
        return
    if event.is_action_pressed("left_mouse"):
        animation_player.play("open")
