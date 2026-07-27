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
# Trail gold is deliberately DARKER than the per-room ring gold (#f0c040): the ring
# reads fine against the icons, but 30px dashes of light gold nearly vanished on the
# light parchment (checked on render) - a deeper amber holds contrast there.
const LINE_TRAIL_COLOR := Color("#c9820e")
const LINE_DEFAULT_COLOR := Color("#8B5E1A")
const LINE_DIM_COLOR := Color("#4A3210")
const LINE_DIM_ALPHA := 0.45
const LINE_BRIGHT_ALPHA := 1.0
const LINE_WIDTH := 30.0
const LINE_TRAIL_WIDTH := 36.0

# Relevance tinting (see _refresh_room_relevance): brightness-multiply on each room's
# Visuals so the live frontier is the brightest thing on the sheet. Walked rooms dim a
# little (their gold ring carries the trail), skipped/passed rooms dim hard, and rooms
# that are still ahead but can no longer be reached from your position dim halfway -
# honest "don't plan around this shop" information the line colors only hinted at.
# Deliberately SUBTLE (Julien: "you can slightly darken them but nowhere close that" -
# the first pass at 0.42/0.62 read as switched-off rooms rather than de-emphasized ones).
# The map is a planning screen: every room must stay comfortably readable, the tint only
# ranks them.
const ROOM_TINT_CURRENT := Color.WHITE
const ROOM_TINT_WALKED := Color(0.88, 0.88, 0.88)
const ROOM_TINT_PASSED := Color(0.78, 0.78, 0.78)
const ROOM_TINT_UNREACHABLE := Color(0.85, 0.85, 0.85)

# One-time reveal when a freshly generated map first becomes visible (run start / act
# transition / load): rooms pop in bottom-up, lines fade in behind them.
const ENTRANCE_ROW_STAGGER := 0.055

# "You are here" die pawn: a small d6 standing on the current room (board-game piece,
# NOT a ring - ring/disc markers were rejected). It hops to the picked room during the
# 0.6s the select animation already waits before run.gd swaps views.
const PAWN_DIE_TEXTURE := preload("res://blue6.png")
const PAWN_SIZE := 30.0
# Front-left corner of the tile, board-game style - centered on the room it covered
# the icon art (die parked dead on the campfire logs, checked on render).
const PAWN_ROOM_OFFSET := Vector2(-26, 12)
const PAWN_HOP_TIME := 0.42
const PAWN_HOP_HEIGHT := 26.0

@onready var map_generator: MapGenerator = $MapGenerator
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var visuals: Node2D = $Visuals
@onready var camera_2d: Camera2D = $Camera2D
@onready var map_legend: CanvasLayer = $MapLegend
@onready var map_vignette: CanvasLayer = $MapVignette
@onready var paper_background: Sprite2D = $PaperBackground

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

# Entrance reveal (armed by create_map, consumed the first time the new map is shown)
var _pending_entrance := false

# "You are here" pawn (built lazily in code - lives under Visuals, in room-position space)
var _pawn: Node2D
var _pawn_die: Sprite2D
var _pawn_travel_tween: Tween
var _pawn_bob_tween: Tween


# =========================================================
# READY
# =========================================================

func _ready() -> void:
    camera_edge_y = MapGenerator.Y_DIST * (MapGenerator.FLOORS - 1)
    _setup_paper_background()


# World-space parchment: the sheet scrolls 1:1 with the rooms/lines (the pins sit ON
# the paper) instead of the old screen-fixed CanvasLayer wallpaper the map visibly slid
# over. Sized to cover every world position the clamped camera can ever show, tiled
# vertically with MIRROR repeat (set on the node) so the 1200px-tall scroll.jpg covers
# the ~2470 world-px sheet without a visible seam. The .tscn carries baked defaults for
# the 1280x720 design resolution; this recomputes them so a future FLOORS/viewport
# change can't silently crop the paper.
func _setup_paper_background() -> void:
    var viewport_size := get_viewport_rect().size
    var texture_width := float(paper_background.texture.get_width())
    var paper_scale := viewport_size.x / texture_width
    var world_height := camera_edge_y + viewport_size.y
    paper_background.position = Vector2(0, -camera_edge_y)
    paper_background.scale = Vector2(paper_scale, paper_scale)
    paper_background.region_rect = Rect2(0, 0, texture_width, world_height / paper_scale)


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

    _ensure_pawn()
    _position_pawn_at_home()

    # Arm the one-time entrance reveal. At run start the map is ALREADY on screen when
    # the first map generates (run.tscn boots with the map view visible - show_map() is
    # never called), so play it directly; on an act transition the map is hidden while
    # it regenerates and show_map() consumes the flag instead. Deferred one frame so
    # every spawned room has run its _ready.
    _pending_entrance = true
    if visible:
        call_deferred("_play_entrance_reveal")


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
    new_map_room.pick_started.connect(_on_map_room_pick_started)

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
        new_map_line.width = LINE_WIDTH
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
    _refresh_room_relevance()
    refresh_affordable_badges()


func unlock_next_rooms() -> void:

    if last_room == null:
        return

    for map_room: MapRoom in rooms.get_children():

        if last_room.next_rooms.has(map_room.room):
            map_room.available = true

    _refresh_line_visibility()
    _refresh_room_relevance()
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
            line.width = LINE_TRAIL_WIDTH
            continue

        var to_map_room: MapRoom = _room_lookup.get(to)
        if to_map_room and to_map_room.available:
            line.default_color = LINE_DEFAULT_COLOR
            line.modulate.a = LINE_BRIGHT_ALPHA
            line.width = LINE_WIDTH
        else:
            line.default_color = LINE_DIM_COLOR
            line.modulate.a = LINE_DIM_ALPHA
            line.width = LINE_WIDTH


# =========================================================
# SHOW / HIDE
# =========================================================
func hide_map() -> void:
    hide()
    map_legend.hide()
    # CanvasLayer children (map_legend above, map_vignette here) don't inherit visibility
    # from a hidden Node2D parent - Map's own hide() above only affects normal 2D children
    # (paper/rooms/lines/visuals). The vignette layer (ex-MapBackground, which held the
    # screen-fixed parchment before it moved into world space) must be toggled explicitly,
    # or it keeps rendering over every other screen (battle/shop/campfire/...).
    map_vignette.hide()
    camera_2d.enabled = false

func show_map() -> void:
    show()
    map_legend.show()
    map_vignette.show()
    camera_2d.enabled = true
    _focus_camera_on_current_floor()
    _position_pawn_at_home()
    if _pending_entrance:
        _play_entrance_reveal()

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

    # Dim the row you just left behind right away (the picked room itself stays bright -
    # it's the pawn's destination; it drops to the walked tint on the next map visit).
    _refresh_room_relevance()


    Events.map_exited.emit(room)


    await get_tree().create_timer(0.1).timeout

    selection_in_progress = false


# =========================================================
# ROOM RELEVANCE (icon dimming)
# =========================================================

# Companion to _refresh_line_visibility, for the icons themselves: before this, every
# room on the whole map rendered at full brightness forever, so nothing separated your
# path and your options from rows you passed 10 floors ago. Tint rules (constants at
# the top): current room bright, walked rooms slightly dimmed (their ring carries the
# trail), passed rows heavily dimmed, still-ahead-but-unreachable rooms halfway dimmed.
func _refresh_room_relevance() -> void:
    var reachable := _compute_reachable_rooms()
    for map_room: MapRoom in rooms.get_children():
        var room: Room = map_room.room
        var tint := ROOM_TINT_CURRENT
        if room == last_room:
            tint = ROOM_TINT_CURRENT
        elif room.selected:
            tint = ROOM_TINT_WALKED
        elif room.row < floors_climbed:
            tint = ROOM_TINT_PASSED
        elif not reachable.has(room):
            tint = ROOM_TINT_UNREACHABLE
        map_room.set_relevance_tint(tint)


# Rooms reachable from the current position by walking next_rooms forward. Before the
# first pick (last_room == null) everything is reachable by definition.
func _compute_reachable_rooms() -> Dictionary:
    var reachable := {}
    if last_room == null:
        for row: Array in map_data:
            for room: Room in row:
                reachable[room] = true
        return reachable
    reachable[last_room] = true
    var frontier: Array = [last_room]
    while not frontier.is_empty():
        var current: Room = frontier.pop_back()
        for next: Room in current.next_rooms:
            if not reachable.has(next):
                reachable[next] = true
                frontier.append(next)
    return reachable


# =========================================================
# ENTRANCE REVEAL
# =========================================================

# One-time bottom-up reveal when a freshly generated map is first seen: rooms pop in
# row by row, lines fade in just behind their origin room, the pawn fades in early.
# Rooms stay clickable throughout (no input blocking - it's ~1s of flourish, not a
# cutscene). Line tweens capture the alpha _refresh_line_visibility already assigned
# and restore it, so the dim/bright states land exactly where they were.
func _play_entrance_reveal() -> void:
    if not _pending_entrance:
        return
    _pending_entrance = false
    for map_room: MapRoom in rooms.get_children():
        map_room.play_entrance(map_room.room.row * ENTRANCE_ROW_STAGGER + randf() * 0.03)
    for edge: Dictionary in _line_edges:
        var line: Line2D = edge["line"]
        var from: Room = edge["from"]
        var target_alpha: float = line.modulate.a
        line.modulate.a = 0.0
        var tween := line.create_tween()
        tween.tween_interval(from.row * ENTRANCE_ROW_STAGGER + 0.1)
        tween.tween_property(line, "modulate:a", target_alpha, 0.25)
    if _pawn:
        _pawn.modulate.a = 0.0
        var pawn_tween := _pawn.create_tween()
        pawn_tween.tween_interval(0.25)
        pawn_tween.tween_property(_pawn, "modulate:a", 1.0, 0.25)


# =========================================================
# "YOU ARE HERE" PAWN
# =========================================================

func _ensure_pawn() -> void:
    if _pawn:
        return
    _pawn = Node2D.new()
    _pawn.z_index = 10

    # Grounding shadow: the same soft radial the glow uses, squashed flat and black -
    # stays put while the die bobs above it.
    var shadow := Sprite2D.new()
    shadow.texture = MapRoom._get_glow_texture()
    shadow.modulate = Color(0, 0, 0, 0.35)
    shadow.scale = Vector2(0.22, 0.1)
    shadow.position = Vector2(0, PAWN_SIZE * 0.42)
    _pawn.add_child(shadow)

    _pawn_die = Sprite2D.new()
    _pawn_die.texture = PAWN_DIE_TEXTURE
    var die_scale := PAWN_SIZE / PAWN_DIE_TEXTURE.get_width()
    _pawn_die.scale = Vector2(die_scale, die_scale)
    _pawn.add_child(_pawn_die)

    # Child of Visuals (added after Lines/Rooms, so it draws on top) - pawn positions
    # are straight room.position values, no coordinate conversion anywhere.
    visuals.add_child(_pawn)
    _start_pawn_bob()


# Idle bob on the die's POSITION, never its scale (a scale pulse on a ~30px sprite
# shimmers - see the intent-icon lesson). The shadow stays grounded.
func _start_pawn_bob() -> void:
    if _pawn_bob_tween and _pawn_bob_tween.is_valid():
        _pawn_bob_tween.kill()
    _pawn_die.position.y = 0.0
    _pawn_bob_tween = _pawn_die.create_tween().set_loops()
    _pawn_bob_tween.tween_property(_pawn_die, "position:y", -3.0, 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _pawn_bob_tween.tween_property(_pawn_die, "position:y", 0.0, 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Where the pawn belongs when nothing is in flight: standing on the current room, or -
# before the first pick - at a "trailhead" below floor 0, center-bottom of the sheet.
func _pawn_home_position() -> Vector2:
    if last_room != null:
        return last_room.position + PAWN_ROOM_OFFSET
    var map_center_x := MapGenerator.X_DIST * (MapGenerator.MAP_WIDTH - 1) * 0.5
    return Vector2(map_center_x, MapGenerator.Y_DIST * 0.85)


func _position_pawn_at_home() -> void:
    if _pawn == null:
        return
    if _pawn_travel_tween and _pawn_travel_tween.is_valid():
        _pawn_travel_tween.kill()
    _pawn.position = _pawn_home_position()


# Fired the instant a room is clicked (MapRoom.pick_started) - the hop plays out
# inside the 0.6s the select animation already waits before emitting map_exited, so
# the pawn lands just before the view transition.
func _on_map_room_pick_started(room: Room) -> void:
    _ensure_pawn()
    _pawn_travel_to(room.position + PAWN_ROOM_OFFSET)


func _pawn_travel_to(target: Vector2) -> void:
    if _pawn_travel_tween and _pawn_travel_tween.is_valid():
        _pawn_travel_tween.kill()
    var start: Vector2 = _pawn.position
    _pawn_travel_tween = create_tween()
    _pawn_travel_tween.tween_method(
        func(t: float) -> void:
            _pawn.position = start.lerp(target, t) + Vector2(0, -sin(t * PI) * PAWN_HOP_HEIGHT),
        0.0, 1.0, PAWN_HOP_TIME
    ).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _pawn_travel_tween.tween_callback(_pawn_land_squash)


# Landing accent on the die sprite - a deliberate one-shot impact squash (same idea as
# the thrown-dice slam squash), not an ambient scale pulse.
func _pawn_land_squash() -> void:
    var die_scale := PAWN_SIZE / PAWN_DIE_TEXTURE.get_width()
    var squash_tween := _pawn_die.create_tween()
    squash_tween.tween_property(_pawn_die, "scale", Vector2(die_scale * 1.18, die_scale * 0.8), 0.07)
    squash_tween.tween_property(_pawn_die, "scale", Vector2(die_scale, die_scale), 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
