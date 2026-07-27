class_name MapGenerator
extends Node


const X_DIST := 150
const Y_DIST := 125
# 22 (was 5): ±5px on a 150x125 grid read as a spreadsheet, not a hand-drawn map.
# Worst-case neighbor drift is ±22px, leaving ~103px between click circles (2x44.83
# radius = ~90px), so no overlap is possible. Saved runs keep their stored positions.
const PLACEMENT_RANDOMNESS := 22
const FLOORS := 15
const MAP_WIDTH := 7
const PATHS := 6
const MONSTER_ROOM_WEIGHT := 5.5
const ELITE_ROOM_WEIGHT := 1.2
const CAMPFIRE_ROOM_WEIGHT := 1.5
const SHOP_ROOM_WEIGHT := 0.8
const BOSS_ROOM_WEIGHT := 0.0
const TREASURE_ROOM_WEIGHT := 0.0
const EVENT_ROOM_WEIGHT := 3.0
const EVENT_FIGHT_CHANCE := 0.1

@export var battle_stats_pool: BattleStatsPool
@export var event_stats_pool: EventStatsPool

var map_data: Array[Array]

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
    # Fixed floors are assigned BEFORE the random rooms (used to be after) so the
    # quota bag below is computed over exactly the rooms that stay random - dealing
    # a type onto row 7/13 only for the treasure/campfire pass to overwrite it would
    # silently skew the map's composition.
    _setup_treasure_floor()
    _setup_campfire_floor()
    _setup_room_types()

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


# STS-style assignment (replaced the old per-node independent weighted rolls, 2026-07-05):
# 1. Count the on-path rooms that need a random type, build a fixed "bag" of room types
#    matching the weight proportions exactly, shuffle it, and deal it onto the map. Every
#    map therefore has (nearly) the SAME composition - the randomness is only in the
#    arrangement. The old i.i.d. rolls produced wild per-map swings (shopless maps, elite
#    droughts, event floods) with the same average.
# 2. Sibling diversity: when dealing, a room avoids taking the same type as an
#    already-assigned sibling (child of a shared parent) as long as the bag can offer an
#    alternative - so a fork almost always presents a real choice between different room
#    types instead of monster-vs-monster.
# Hard rules (never relaxed) are unchanged from the old roller: no elite/campfire before
# row 5, no campfire on row 12, no same-type parent->child for shop/elite/campfire.
func _setup_room_types() -> void:
    for room: Room in map_data[0]:
        if room.next_rooms.size() > 0:
            room.type = Room.Type.MONSTER
            room.battle_stats = battle_stats_pool.get_random_battle_for_tier(0)

    # Every on-path room in rows 1..13 that the fixed passes (treasure row 7,
    # campfire row 13, boss) haven't already typed. Row-ordered top-down, which
    # matters: early rows legally can't take elite/campfire, so dealing top-down
    # lets those types survive in the bag until the rows that can host them.
    var assignable: Array[Room] = []
    for i in range(1, FLOORS - 1):
        for room: Room in map_data[i]:
            if room.next_rooms.size() > 0 and room.type == Room.Type.NOT_ASSIGNED:
                assignable.append(room)

    var bag := _build_room_type_bag(assignable.size())

    for room in assignable:
        var dealt := _deal_type_from_bag(room, bag, true)
        if not dealt:
            # No bag entry satisfies sibling diversity - relax it (hard rules still apply).
            dealt = _deal_type_from_bag(room, bag, false)
        if not dealt:
            # Nothing legal at all (e.g. only elites left for an early row) - filler
            # monster, without consuming the bag. Same fallback STS uses.
            room.type = Room.Type.MONSTER
        _finalize_room(room)


# Fixed quota of each type from the same weight constants as before (weight / total
# = share of the map). Monster is the remainder, so the bag always matches the room
# count exactly.
func _build_room_type_bag(room_count: int) -> Array:
    var total_weight := MONSTER_ROOM_WEIGHT + ELITE_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT \
        + SHOP_ROOM_WEIGHT + EVENT_ROOM_WEIGHT
    var bag := []

    for type_and_weight in [
        [Room.Type.ELITE, ELITE_ROOM_WEIGHT],
        [Room.Type.CAMPFIRE, CAMPFIRE_ROOM_WEIGHT],
        [Room.Type.SHOP, SHOP_ROOM_WEIGHT],
        [Room.Type.EVENT, EVENT_ROOM_WEIGHT],
    ]:
        var count := int(round(float(room_count) * float(type_and_weight[1]) / total_weight))
        for i in count:
            bag.append(type_and_weight[0])

    while bag.size() < room_count:
        bag.append(Room.Type.MONSTER)
    while bag.size() > room_count:
        bag.pop_back()

    bag.shuffle()
    return bag


# Assign the first bag entry this room may legally take (bag is shuffled, so "first
# fitting" = uniform among the remaining quota). Returns false if none fits.
func _deal_type_from_bag(room: Room, bag: Array, avoid_sibling_duplicates: bool) -> bool:
    for idx in bag.size():
        var candidate: Room.Type = bag[idx]
        if _is_type_allowed(room, candidate, avoid_sibling_duplicates):
            room.type = candidate
            bag.remove_at(idx)
            return true
    return false


func _is_type_allowed(room: Room, candidate: Room.Type, avoid_sibling_duplicates: bool) -> bool:
    match candidate:
        Room.Type.ELITE:
            if room.row < 5:
                return false
            if _room_has_parent_of_type(room, Room.Type.ELITE):
                return false
        Room.Type.CAMPFIRE:
            if room.row < 5:
                return false
            if room.row == 12:
                return false
            if _room_has_parent_of_type(room, Room.Type.CAMPFIRE):
                return false
        Room.Type.SHOP:
            if _room_has_parent_of_type(room, Room.Type.SHOP):
                return false

    if avoid_sibling_duplicates and _get_assigned_sibling_types(room).has(candidate):
        return false

    return true


# Types already assigned to this room's siblings (other children of any shared parent).
# Only already-assigned siblings count - rooms are dealt in row/column order, so a left
# sibling constrains its right neighbour, same as STS.
func _get_assigned_sibling_types(room: Room) -> Array:
    var types := []
    if room.row == 0:
        return types

    for dj in [-1, 0, 1]:
        var pj: int = room.column + dj
        if pj < 0 or pj >= MAP_WIDTH:
            continue
        var parent := map_data[room.row - 1][pj] as Room
        if not parent.next_rooms.has(room):
            continue
        for sibling: Room in parent.next_rooms:
            if sibling != room and sibling.type != Room.Type.NOT_ASSIGNED:
                types.append(sibling.type)

    return types


# Post-assignment side effects, unchanged from the old roller. The battle_stats /
# event_stats pre-assignments are overridden by run.gd at room entry (run.gd is
# authoritative for tiers) - kept for safety; is_secret_fight however IS live.
func _finalize_room(room: Room) -> void:
    match room.type:
        Room.Type.MONSTER:
            var tier_for_monster_rooms := 0
            if room.row > 2:
                tier_for_monster_rooms = 1
            if room.row > 7:
                tier_for_monster_rooms = 2
            room.battle_stats = battle_stats_pool.get_random_battle_for_tier(tier_for_monster_rooms)
        Room.Type.ELITE:
            room.battle_stats = battle_stats_pool.get_random_battle_for_tier(3)
        Room.Type.EVENT:
            if randf() < EVENT_FIGHT_CHANCE:
                room.is_secret_fight = true
            else:
                var tier_for_event_rooms := 0
                if room.row > 2:
                    tier_for_event_rooms = 1
                room.event_stats = event_stats_pool.get_random_event_for_tier(tier_for_event_rooms)


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

