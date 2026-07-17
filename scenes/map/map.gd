class_name Map
extends Node2D

const SCROLL_SPEED := 200.0
const MAP_ROOM = preload("res://scenes/map/map_room.tscn")
const MAP_LINE = preload("res://scenes/map/map_line.tscn")

# Path-clarity recolor for connection lines (see _refresh_line_visibility): lines you actually
# walked turn gold to match the per-room selected ring; everything else either stays the normal
# rope color (if it's a live choice right now) or fades way down (if it's neither your trail nor
# currently reachable) - cuts the full always-on lattice down to "your path" + "your options".
# Dimmed lines use their own darker color rather than just LINE_DEFAULT_COLOR at low alpha -
# a lighter brown at low alpha washed out to near-invisible against the parchment's lighter
# patches (Julien: "barely visible against lighter parchment"); a darker base color holds up
# at low alpha instead of relying on alpha alone for contrast.
const LINE_TRAIL_COLOR := Color("#f0c040")
const LINE_DEFAULT_COLOR := Color("#8B5E1A")
const LINE_DIM_COLOR := Color("#4A3210")
const LINE_DIM_ALPHA := 0.45
const LINE_BRIGHT_ALPHA := 1.0

@onready var map_generator: MapGenerator = $MapGenerator
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var visuals: Node2D = $Visuals
@onready var camera_2d: Camera2D = $Camera2D
@onready var map_legend: CanvasLayer = $MapLegend
@onready var map_background: CanvasLayer = $MapBackground

var map_data: Array[Array]
var floors_climbed: int
var last_room: Room
var camera_edge_y: float

# (from Room, to Room, Line2D) triples for every connection drawn, kept around so line color/
# alpha can be re-evaluated any time availability changes instead of only once at map generation.
var _line_edges: Array[Dictionary] = []
# Room -> MapRoom, so _refresh_line_visibility can check a Room's live `available` state without
# every edge needing its own node reference.
var _room_lookup: Dictionary = {}

# Drag scrolling
var dragging := false

# Selection safety
var selection_in_progress := false


# =========================================================
# READY
# =========================================================

func _ready() -> void:
    camera_edge_y = MapGenerator.Y_DIST * (MapGenerator.FLOORS - 1)


# =========================================================
# PROCESS — continuous input (keys)
# =========================================================

func _process(delta: float) -> void:

    var move := 0.0

    if Input.is_action_pressed("scroll_up"):
        move -= 1.0

    if Input.is_action_pressed("scroll_down"):
        move += 1.0

    camera_2d.position.y += move * SCROLL_SPEED * delta

    _clamp_camera()


# =========================================================
# INPUT — mouse wheel + drag
# =========================================================

func _input(event: InputEvent) -> void:

    # Mouse wheel
    if event is InputEventMouseButton:

        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            camera_2d.position.y -= SCROLL_SPEED * 0.15

        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            camera_2d.position.y += SCROLL_SPEED * 0.15

        # Drag start / stop
        elif event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed


    # Drag motion
    elif event is InputEventMouseMotion and dragging:
        camera_2d.position.y -= event.relative.y

    _clamp_camera()


# =========================================================
# CAMERA SAFETY
# =========================================================

func _clamp_camera() -> void:
    camera_2d.position.y = clamp(camera_2d.position.y, -camera_edge_y, 0)


# =========================================================
# MAP GENERATION
# =========================================================

func generate_new_map() -> void:

    floors_climbed = 0
    last_room = null

    _clear_map()

    map_data = map_generator.generate_map()

    create_map()


# Regeneration support (act 2): the first generate_new_map() call runs on an empty
# scene, but a second call (new act) must drop every node and lookup built for the
# previous map, or rooms/lines double up and _refresh_line_visibility keeps reading
# stale, freed edges.
func _clear_map() -> void:
    for child in rooms.get_children():
        child.queue_free()
    for child in lines.get_children():
        child.queue_free()
    _line_edges.clear()
    _room_lookup.clear()


func create_map() -> void:

    for current_floor: Array in map_data:

        for room: Room in current_floor:

            if room.next_rooms.size() > 0:
                _spawn_room(room)


    # Spawn final boss
    var middle := floori(MapGenerator.MAP_WIDTH * 0.5)
    _spawn_room(map_data[MapGenerator.FLOORS - 1][middle])


    # Center visuals
    var map_width_pixels := MapGenerator.X_DIST * (MapGenerator.MAP_WIDTH - 1)

    visuals.position.x = (get_viewport_rect().size.x - map_width_pixels) / 2
    visuals.position.y = get_viewport_rect().size.y / 2


# =========================================================
# SAVE / LOAD (see global/save_manager.gd for the format rationale)
# =========================================================

# Serializes the room graph to plain data. Only on-path rooms (next_rooms > 0) and the boss
# are saved - they're the only ones create_map() ever spawns; off-path grid slots are
# regenerated as blank Room.new()s on load. Room links are stored as next-row COLUMN indexes
# (a room's next_rooms always live on row + 1), so no object references end up in the file.
func get_save_data() -> Dictionary:
    var rooms_out: Array = []
    for current_floor: Array in map_data:
        for room: Room in current_floor:
            if room.next_rooms.is_empty() and room.type != Room.Type.BOSS:
                continue
            var next_columns: Array = []
            for next: Room in room.next_rooms:
                next_columns.append(next.column)
            rooms_out.append({
                "row": room.row,
                "column": room.column,
                "type": room.type,
                "position": room.position,
                "selected": room.selected,
                "secret": room.is_secret_fight,
                "battle": room.battle_stats.resource_path if room.battle_stats else "",
                "event": room.event_stats.resource_path if room.event_stats else "",
                "next_columns": next_columns,
            })
    var last: Variant = null
    if last_room != null:
        last = [last_room.row, last_room.column]
    return {
        "floors_climbed": floors_climbed,
        "last_room": last,
        "rooms": rooms_out,
    }


# Rebuilds map_data + visuals from get_save_data() output. Mirrors generate_new_map()'s
# structure (clear -> fill map_data -> create_map) so all the node/lookup lifecycle fixed
# for act-2 regeneration applies here too. Caller (run.gd) is responsible for the unlock
# call afterwards (unlock_next_rooms / unlock_floor) - same split as a fresh run.
func load_from_save_data(data: Dictionary) -> void:
    floors_climbed = data["floors_climbed"]
    last_room = null
    _clear_map()

    var rebuilt: Array[Array] = []
    for i in MapGenerator.FLOORS:
        var row_rooms: Array[Room] = []
        for j in MapGenerator.MAP_WIDTH:
            var room := Room.new()
            room.row = i
            room.column = j
            room.next_rooms = []
            row_rooms.append(room)
        rebuilt.append(row_rooms)
    map_data = rebuilt

    # Pass 1: per-room fields. Pass 2 below wires next_rooms, once every target exists.
    for entry: Dictionary in data["rooms"]:
        var room: Room = map_data[entry["row"]][entry["column"]]
        room.type = entry["type"]
        room.position = entry["position"]
        room.selected = entry["selected"]
        room.is_secret_fight = entry["secret"]
        if entry["battle"] != "" and ResourceLoader.exists(entry["battle"]):
            room.battle_stats = load(entry["battle"])
        if entry["event"] != "" and ResourceLoader.exists(entry["event"]):
            room.event_stats = load(entry["event"])

    for entry: Dictionary in data["rooms"]:
        var room: Room = map_data[entry["row"]][entry["column"]]
        for next_column in entry["next_columns"]:
            room.next_rooms.append(map_data[entry["row"] + 1][next_column])

    if data["last_room"] != null:
        last_room = map_data[data["last_room"][0]][data["last_room"][1]]

    create_map()


# =========================================================
# ROOM SPAWNING
# =========================================================

func _spawn_room(room: Room) -> void:

    var new_map_room := MAP_ROOM.instantiate() as MapRoom

    rooms.add_child(new_map_room)

    new_map_room.room = room

    new_map_room.selected.connect(_on_map_room_selected)

    _room_lookup[room] = new_map_room

    _connect_lines(room)


    if room.selected and room.row < floors_climbed:
        new_map_room.show_selected()


func _connect_lines(room: Room) -> void:

    if room.next_rooms.is_empty():
        return

    for next: Room in room.next_rooms:

        var new_map_line := MAP_LINE.instantiate() as Line2D

        new_map_line.add_point(room.position)
        new_map_line.add_point(next.position)
        lines.add_child(new_map_line)
        new_map_line.default_color = LINE_DIM_COLOR
        new_map_line.width = 30.0
        new_map_line.modulate.a = LINE_DIM_ALPHA

        _line_edges.append({"line": new_map_line, "from": room, "to": next})


# =========================================================
# ROOM UNLOCKING
# =========================================================

func unlock_floor(which_floor: int = floors_climbed) -> void:

    for map_room: MapRoom in rooms.get_children():

        if map_room.room.row == which_floor:
            map_room.available = true

    _refresh_line_visibility()
    refresh_affordable_badges()


func unlock_next_rooms() -> void:

    if last_room == null:
        return

    for map_room: MapRoom in rooms.get_children():

        if last_room.next_rooms.has(map_room.room):
            map_room.available = true

    _refresh_line_visibility()
    refresh_affordable_badges()


# =========================================================
# "CAN AFFORD A DICE" REMINDER BADGE
# =========================================================

# Same threshold as the top-bar Dice Shop glow (run.gd::_on_check_if_can_purchase_dice) -
# re-run here too, on every gold change, so the reminder shows up right where a player is
# about to commit to a room rather than only on the shop icon itself (which is easy to miss
# on the way to clicking a fight).
func refresh_affordable_badges() -> void:
    var can_afford: bool = Global.cheapest_dice_price != null and Global.gold >= Global.cheapest_dice_price
    for map_room: MapRoom in rooms.get_children():
        map_room.set_show_affordable_badge(can_afford and map_room.available)


# =========================================================
# PATH CLARITY (connection line dimming)
# =========================================================

# A line is bright if it's either the exact edge you walked (both ends selected - safe even on
# diamond crossings where a room has two possible parents, since at most one parent per row can
# ever be selected in a single run) or it leads INTO a room you can pick right now (`to`, not
# `from` - the fix for a one-row-ahead bug: checking `from.available` instead lit the edges going
# OUT of your current choices, i.e. one row further than the actual live frontier). Everything
# else - alternate branches from rooms you've already passed, or anything further out than your
# current choices - fades down instead of competing with those for attention.
func _refresh_line_visibility() -> void:
    for edge: Dictionary in _line_edges:
        var from: Room = edge["from"]
        var to: Room = edge["to"]
        var line: Line2D = edge["line"]

        if from.selected and to.selected:
            line.default_color = LINE_TRAIL_COLOR
            line.modulate.a = LINE_BRIGHT_ALPHA
            continue

        var to_map_room: MapRoom = _room_lookup.get(to)
        if to_map_room and to_map_room.available:
            line.default_color = LINE_DEFAULT_COLOR
            line.modulate.a = LINE_BRIGHT_ALPHA
        else:
            line.default_color = LINE_DIM_COLOR
            line.modulate.a = LINE_DIM_ALPHA


# =========================================================
# SHOW / HIDE
# =========================================================
func hide_map() -> void:
    hide()
    map_legend.hide()
    # CanvasLayer children (map_legend above, map_background here) don't inherit visibility
    # from a hidden Node2D parent - Map's own hide() above only affects normal 2D children
    # (rooms/lines/visuals). map_background was never toggled at all before this fix, so its
    # layer=-1 parchment kept rendering behind every other screen (battle/shop/campfire/...)
    # for the rest of the run, bleeding through any tiny coverage gap in whatever sits on top.
    map_background.hide()
    camera_2d.enabled = false

func show_map() -> void:
    show()
    map_legend.show()
    map_background.show()
    camera_2d.enabled = true
    _focus_camera_on_current_floor()

func _focus_camera_on_current_floor() -> void:
    var target_y := -floors_climbed * MapGenerator.Y_DIST
    target_y = clamp(target_y, -camera_edge_y, 0)
    camera_2d.position.y = target_y
    


# =========================================================
# ROOM SELECTION
# =========================================================

func _on_map_room_selected(room: Room) -> void:

    if selection_in_progress:
        return

    selection_in_progress = true


    # Lock other rooms on same row
    for map_room: MapRoom in rooms.get_children():

        if map_room.room.row == room.row:
            map_room.available = false

    refresh_affordable_badges()

    last_room = room

    floors_climbed += 1


    Events.map_exited.emit(room)


    await get_tree().create_timer(0.1).timeout

    selection_in_progress = false
