class_name Map
extends Node2D

const SCROLL_SPEED := 200.0
const MAP_ROOM = preload("res://scenes/map/map_room.tscn")
const MAP_LINE = preload("res://scenes/map/map_line.tscn")

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
        new_map_line.default_color = Color("#8B5E1A")
        new_map_line.width = 30.0


# =========================================================
# ROOM UNLOCKING
# =========================================================

func unlock_floor(which_floor: int = floors_climbed) -> void:

    for map_room: MapRoom in rooms.get_children():

        if map_room.room.row == which_floor:
            map_room.available = true


func unlock_next_rooms() -> void:

    if last_room == null:
        return

    for map_room: MapRoom in rooms.get_children():

        if last_room.next_rooms.has(map_room.room):
            map_room.available = true


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
