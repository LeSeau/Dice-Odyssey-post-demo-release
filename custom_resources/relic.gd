class_name Relic
extends Resource

enum Type {START_OF_TURN, START_OF_COMBAT, END_OF_TURN, END_OF_COMBAT, EVENT_BASED}

@export var relic_name: String
@export var id: String
@export var type: Type
@export var has_counter: bool = false
@export var counter: int
@export var starter_relic: bool = false
@export var icon: Texture
@export_multiline var tooltip: String


func initialize_relic(_owner: RelicUI) -> void:
    pass
    
func activate_relic(_owner: RelicUI) -> void:
    pass
    
    
#this method should be implemnted by event-based relics
#which connect to the event bus to make sure that they are
#disconnected when a relic gets removed

func deactivate_relic(_owner: RelicUI) -> void:
    pass 

func get_tooltip() -> String:
    return tooltip 
    
func can_appear_as_reward(character: CharacterStats) -> bool:
    if starter_relic:
        return false
    return true
