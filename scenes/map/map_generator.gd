class_name MapGenerator
extends Node


const X_DIST := 150
const Y_DIST := 125
const PLACEMENT_RANDOMNESS := 5
const FLOORS := 15
const MAP_WIDTH := 7
const PATHS := 6
const MONSTER_ROOM_WEIGHT := 5.5
const ELITE_ROOM_WEIGHT := 1.6
const CAMPFIRE_ROOM_WEIGHT := 1.2
const SHOP_ROOM_WEIGHT := 0.0
const BOSS_ROOM_WEIGHT := 0.0
const TREASURE_ROOM_WEIGHT := 0.0
const EVENT_ROOM_WEIGHT := 3.0

@export var battle_stats_pool: BattleStatsPool
@export var event_stats_pool: EventStatsPool

var random_room_type_weights = {
    Room.Type.MONSTER: 0.0,
    Room.Type.ELITE: 0.0,
    Room.Type.CAMPFIRE: 0.0,
    Room.Type.TREASURE: 0.0,
    Room.Type.BOSS: 0.0,
    Room.Type.SHOP: 0.0,
    Room.Type.EVENT: 0.0
}

var random_room_type_total_weight := 0
var map_data: Array [Array]

func generate_map() -> Array[Array]:
    map_data = _generate_initial_grid()
    var starting_points := _get_random_starting_points() 
    
    for j in starting_points:
        var current_j := j 
        for i in FLOORS - 1:
            current_j = _setup_connection(i, current_j)
        
    battle_stats_pool.setup()
    event_stats_pool.setup()
           
    _setup_boss_room()
    _setup_random_room_weights()
    _setup_room_types()
    _setup_treasure_floor()  
    _setup_campfire_floor()
        
    return map_data

func _generate_initial_grid() -> Array[Array]:
    var result: Array[Array] = []
    
    for i in FLOORS:
        var adjacent_rooms: Array[Room] = [] 
        
        for j in MAP_WIDTH:
            var current_room := Room.new()
            var offset := Vector2(randf(), randf()) * PLACEMENT_RANDOMNESS
            current_room.position = Vector2(j * X_DIST, i* -Y_DIST) + offset 
            current_room.row = i
            current_room.column = j
            current_room.next_rooms = []
            
            if i == FLOORS - 1:
                current_room.position.y = (i+1) * -Y_DIST

            adjacent_rooms.append(current_room)
            
        result.append(adjacent_rooms)
        
    return result

func _get_random_starting_points() -> Array[int]:
    var y_coordinates: Array[int]
    var unique_points: int = 0
    
    while unique_points < 2:
        unique_points = 0
        y_coordinates = []
        
        for i in PATHS:
            var starting_point := randi_range(0, MAP_WIDTH - 1)
            if not y_coordinates.has(starting_point):
                unique_points+=1
                
            y_coordinates.append(starting_point)
            
    return y_coordinates


func _setup_connection(i: int, j: int) -> int:
    var next_room: Room
    var current_room := map_data[i][j] as Room
    
    while not next_room or _would_cross_existing_path(i, j, next_room):
        var random_j := clampi(randi_range(j - 1, j+1), 0, MAP_WIDTH -1)
        next_room = map_data [i+1] [random_j]
        
    current_room.next_rooms.append(next_room)
    
    return next_room.column

func _would_cross_existing_path(i:int, j:int, room:Room) -> bool:
    var left_neighbour: Room 
    var right_neighbour: Room
    
    if j > 0:
        left_neighbour = map_data[i][j-1]
    if j < MAP_WIDTH - 1:
        right_neighbour = map_data[i][j+1]
        
    if right_neighbour and room.column > j:
        for next_room: Room in right_neighbour.next_rooms:
            if next_room.column < room.column:
                return true
                
    if left_neighbour and room.column < j:
        for next_room: Room in left_neighbour.next_rooms:
            if next_room.column > room.column:
                return true
                
    return false
        
func _setup_boss_room() -> void:
    var middle := floori(MAP_WIDTH * 0.5)
    var boss_room := map_data[FLOORS-1][middle] as Room
    
    for j in MAP_WIDTH:
        var current_room = map_data [FLOORS - 2][j] as Room 
        if current_room.next_rooms:
            current_room.next_rooms = [] as Array[Room]
            current_room.next_rooms.append(boss_room)
            
    boss_room.type = Room.Type.BOSS
    boss_room.battle_stats = battle_stats_pool.get_random_battle_for_tier(2)
    

func _setup_treasure_floor() -> void:
    var treasure_floor := 7   # row 7 = 8th floor (0-indexed)
    for j in MAP_WIDTH:
        var room := map_data[treasure_floor][j] as Room
        if room:  # make sure a room exists here
            room.type = Room.Type.TREASURE
            
func _setup_campfire_floor() -> void:
    var campfire_floor := 13   # row 7 = 8th floor (0-indexed)
    for j in MAP_WIDTH:
        var room := map_data[campfire_floor][j] as Room
        if room:  # make sure a room exists here
            room.type = Room.Type.CAMPFIRE


func _setup_random_room_weights() -> void:
    random_room_type_weights[Room.Type.MONSTER] = MONSTER_ROOM_WEIGHT
    random_room_type_weights[Room.Type.ELITE] = MONSTER_ROOM_WEIGHT + ELITE_ROOM_WEIGHT
    random_room_type_weights[Room.Type.CAMPFIRE] = MONSTER_ROOM_WEIGHT + ELITE_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT    
    random_room_type_weights[Room.Type.SHOP] = MONSTER_ROOM_WEIGHT + ELITE_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT  + SHOP_ROOM_WEIGHT
    random_room_type_weights[Room.Type.BOSS] = MONSTER_ROOM_WEIGHT + ELITE_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT  + SHOP_ROOM_WEIGHT + BOSS_ROOM_WEIGHT
    random_room_type_weights[Room.Type.EVENT] = MONSTER_ROOM_WEIGHT + ELITE_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT  + SHOP_ROOM_WEIGHT + BOSS_ROOM_WEIGHT + EVENT_ROOM_WEIGHT
    random_room_type_total_weight = random_room_type_weights[Room.Type.EVENT]


func _setup_room_types() -> void:
    for room: Room in map_data[0]:
        if room.next_rooms.size() > 0:
            room.type = Room.Type.MONSTER
            room.battle_stats = battle_stats_pool.get_random_battle_for_tier(0)
            
    #add more
    
    #REST OF ROOMS#
    for current_floor in map_data:
        for room: Room in current_floor:
            for next_room: Room in room.next_rooms:
                if next_room.type == Room.Type.NOT_ASSIGNED:
                    _set_room_randomly(next_room)
    
func _set_room_randomly(room_to_set: Room) -> void:
    var consecutive_shop := true
    var consecutive_elite := true
    var consecutive_campfire := true
    var elite_before_floor5 := true
    var campfire_before_floor5 := true
    var campfire_on_floor12 := true   # 🔥 added declaration here

    var type_candidate: Room.Type

    while consecutive_shop \
        or consecutive_elite \
        or consecutive_campfire \
        or elite_before_floor5 \
        or campfire_before_floor5 \
        or campfire_on_floor12:   # 🔥 include in while condition

        type_candidate = _get_random_room_type_by_weight()

        # Shop check
        var is_shop := type_candidate == Room.Type.SHOP
        var has_shop_parent := _room_has_parent_of_type(room_to_set, Room.Type.SHOP)
        consecutive_shop = is_shop and has_shop_parent

        # Elite checks
        var is_elite := type_candidate == Room.Type.ELITE
        var has_elite_parent := _room_has_parent_of_type(room_to_set, Room.Type.ELITE)
        consecutive_elite = is_elite and has_elite_parent
        elite_before_floor5 = is_elite and room_to_set.row < 5

        # Campfire checks
        var is_campfire := type_candidate == Room.Type.CAMPFIRE
        var has_campfire_parent := _room_has_parent_of_type(room_to_set, Room.Type.CAMPFIRE)
        consecutive_campfire = is_campfire and has_campfire_parent
        campfire_before_floor5 = is_campfire and room_to_set.row < 5

        # 🔥 New restriction: no campfire on floor 12 (row 12)
        campfire_on_floor12 = is_campfire and room_to_set.row == 12

    # Once we get here, type_candidate is valid
    room_to_set.type = type_candidate

    if type_candidate == Room.Type.MONSTER:
        var tier_for_monster_rooms := 0
        if room_to_set.row > 2:
            tier_for_monster_rooms = 1
        if room_to_set.row > 8:
            tier_for_monster_rooms = 2
        room_to_set.battle_stats = battle_stats_pool.get_random_battle_for_tier(tier_for_monster_rooms)

    elif type_candidate == Room.Type.ELITE:
        room_to_set.battle_stats = battle_stats_pool.get_random_battle_for_tier(3)
    elif type_candidate == Room.Type.BOSS:
        room_to_set.battle_stats = battle_stats_pool.get_random_battle_for_tier(4)

    elif type_candidate == Room.Type.EVENT:
        var tier_for_event_rooms := 0
        if room_to_set.row > 2:
            tier_for_event_rooms = 1
        room_to_set.event_stats = event_stats_pool.get_random_event_for_tier(tier_for_event_rooms)


func _room_has_parent_of_type(room: Room, type: Room.Type) -> bool:
    var parents: Array[Room] = []
    
    if room.column > 0 and room.row > 0:
        var parent_candidate := map_data[room.row -1] [room.column -1] as Room
        if parent_candidate.next_rooms.has(room):
            parents.append(parent_candidate)
            
    if room.row > 0:
        var parent_candidate := map_data[room.row -1] [room.column] as Room
        if parent_candidate.next_rooms.has(room):
            parents.append(parent_candidate)
            
    if room.column < MAP_WIDTH-1 and room.row > 0:
        var parent_candidate := map_data[room.row -1] [room.column+1] as Room
        if parent_candidate.next_rooms.has(room):
            parents.append(parent_candidate) 
                       
    for parent: Room in parents:
        if parent.type == type:
            return true     
               
    return false      
    
func _get_random_room_type_by_weight() -> Room.Type:
    var roll := randf_range(0.0, random_room_type_total_weight)
    
    for type: Room.Type in random_room_type_weights:
        if random_room_type_weights[type] > roll:
            return type
            
    return Room.Type.MONSTER
    
