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

    map_data = map_generator.generate_map()

    create_map()


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


func unlock_next_rooms() -> void:

    if last_room == null:
        return

    for map_room: MapRoom in rooms.get_children():

        if last_room.next_rooms.has(map_room.room):
            map_room.available = true

    _refresh_line_visibility()


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
    camera_2d.enabled = false

func show_map() -> void:
    show()
    map_legend.show()
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


    last_room = room

    floors_climbed += 1


    Events.map_exited.emit(room)


    await get_tree().create_timer(0.1).timeout

    selection_in_progress = false
