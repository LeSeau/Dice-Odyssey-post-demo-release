class_name Room
extends Resource

enum Type {NOT_ASSIGNED, MONSTER, ELITE, CAMPFIRE, TREASURE, SHOP, BOSS, EVENT}

@export var type: Type
@export var row: int
@export var column: int
@export var position: Vector2
@export var next_rooms: Array [Room]
@export var selected := false
@export var battle_stats: BattleStats #only for monsters & boss
@export var event_stats: EventStats
@export var is_secret_fight := false #EVENT room that secretly resolves to a fight

func _to_string() -> String:
    return "%s (%s)" % [column, Type.keys()[type][0]]
    
