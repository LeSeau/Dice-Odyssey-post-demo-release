class_name RelicHandler
extends HBoxContainer

signal relics_activated(type: Relic.Type)

const RELIC_APPLY_INTERVAL := 0.5
const RELIC_UI = preload("res://scenes/relic_handler/relic_ui.tscn")

@onready var relics_control: RelicsControl = $RelicsControl
# HFlowContainer since 2026-07-31 (was HBoxContainer): the row now spans the screen and
# WRAPS to a second line instead of relics past the 7th being clipped out of existence.
@onready var relics: HFlowContainer = %Relics

func _ready() -> void:
    relics.child_exiting_tree.connect(_on_relics_child_exiting_tree)

    
func activate_relics_by_type(type: Relic.Type) -> void:
    if type == Relic.Type.EVENT_BASED:
        return
    
    var relic_queue: Array[RelicUI] = _get_all_relic_ui_nodes().filter(
        func(relic_ui: RelicUI):
            return relic_ui.relic.type == type
    )
    if relic_queue.is_empty():
        relics_activated.emit(type)
        return
    
    var tween := create_tween()
    for relic_ui: RelicUI in relic_queue:
        tween.tween_callback(relic_ui.relic.activate_relic.bind(relic_ui))
        tween.tween_interval(RELIC_APPLY_INTERVAL)
    
    tween.finished.connect(func(): relics_activated.emit(type))
    
func add_relics(relics_array: Array[Relic]) -> void:
    for relic: Relic in relics_array:
        add_relic(relic)
        
# relic_ui.tscn's own Icon rect (32x32 inside a 56x56 box, see the scene file) is shared with
# shop_relic.tscn's already-tuned display (scaled 3.2x, sized around that exact footprint) -
# touching it there would blow out the shop's shadow/backdrop. Scoped fix instead: only the
# instances THIS handler creates (the top-bar/RelicBar row) get resized, with their icon
# actually filling the box, closing the gap left by relic_ui.tscn's own unused padding.
#
# 46px since 2026-08-06 (was 64). The band this row occupies runs the full screen width and
# floats above every view, so its HEIGHT decides whether the panels underneath stay readable.
# 64px put the band at y 84..164 - exactly the stripe the dice infusion title, "Upgrade a Card"
# and the dice shop panel live in. At 46 the band is y 82..128 and those three were moved just
# below it. Events are the exception and are not solved by size: an event panel needs ~620px
# and starts under the 80px top bar, so no usable icon size fits above one - run.gd hides this
# row for the duration of an event instead.
#
# Sizing is also capacity: at 46 + 3 separation, ~23 relics fit on ONE line between x 20 and
# x 1194 (past that the HFlowContainer wraps to a second row, which would land back on those
# titles). A run realistically ends with 10-18, but if that ever stops being true the fix is a
# "+N" overflow chip rather than shrinking these again.
const TOP_BAR_ICON_SIZE := 46.0

# announce/from_global drive the acquisition beat - see the "Acquisition beat" section at
# the bottom of this file. Both default to off, so all six existing call sites keep behaving
# exactly as they did; only the three that are really the player GAINING something opt in.
func add_relic(relic: Relic, announce := false, from_global := NO_ORIGIN) -> void:
    if has_relic(relic.id):
        return
    var new_relic_ui := RELIC_UI.instantiate() as RelicUI
    _resize_for_top_bar(new_relic_ui)
    relics.add_child(new_relic_ui)
    new_relic_ui.relic = relic  # set_relic handles initialize_relic already
    _make_inspectable(new_relic_ui, relic)
    print("ADDED: ", relic.id)
    AchievementManager.report_relic_count(relics.get_child_count())
    if announce:
        # Deliberately NOT awaited: the relic is already in the bar and already active by
        # this line, and the flight is pure decoration on top of finished state (the same
        # principle as the Power number updating while its orbs are still in the air). An
        # interrupted flight can therefore never cost the player a relic, and add_relic
        # itself stays a plain synchronous function for every existing caller.
        _announce_relic(new_relic_ui, from_global)


const RELIC_INSPECT := preload("res://scenes/ui/relic_inspect.gd")

# Click-to-inspect, Slay the Spire 2 style. Wired HERE and not in relic_ui.gd because that
# scene is shared with shop_relic.tscn, where a click means BUY - the same scoping reason
# _resize_for_top_bar exists. Only the instances this handler builds get the behaviour.
func _make_inspectable(relic_ui: RelicUI, relic: Relic) -> void:
    # Icon and Counter fill the RelicUI and default to mouse_filter STOP, so they would eat
    # the click before RelicUI's gui_input ever saw it (exactly what shop_relic.gd works
    # around). Instance-local, so combat/shop relics are untouched.
    relic_ui.mouse_filter = Control.MOUSE_FILTER_STOP
    var icon := relic_ui.get_node_or_null("Icon") as Control
    if icon:
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var counter := relic_ui.get_node_or_null("Counter") as Control
    if counter:
        counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    relic_ui.gui_input.connect(func(event: InputEvent) -> void:
        if not (event is InputEventMouseButton):
            return
        if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
            return
        # Drop the hover tooltip first, or it sits on top of the popup for its full 8s
        # safety timeout with nothing left to dismiss it.
        relic_ui._cleanup_tooltips()
        RELIC_INSPECT.open(relic, self)
    )

func _resize_for_top_bar(relic_ui: RelicUI) -> void:
    relic_ui.custom_minimum_size = Vector2(TOP_BAR_ICON_SIZE, TOP_BAR_ICON_SIZE)
    relic_ui.offset_right = TOP_BAR_ICON_SIZE
    relic_ui.offset_bottom = TOP_BAR_ICON_SIZE
    # SHRINK_CENTER keeps the icon at its native size, vertically centered in its flow line,
    # instead of the container's default FILL stretching it. That slack is what gives the
    # hover "flash" (Icon scales to 1.2x, see relic_ui.gd) room to breathe - RelicsControl
    # used to clip_contents (for the old scroll pages) and cut the icon off mid-animation.
    relic_ui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var icon := relic_ui.get_node("Icon") as TextureRect
    # custom_minimum_size FIRST, and it is not optional: relic_ui.tscn ships the Icon with a
    # 56x56 minimum, which silently clamps anything smaller however the offsets are set. That
    # never showed while this size was 64 (56 < 64, so the offsets won); at 46 it would have
    # pinned every icon back to 56 and none of the resize below would be visible.
    icon.custom_minimum_size = Vector2(TOP_BAR_ICON_SIZE, TOP_BAR_ICON_SIZE)
    icon.offset_right = TOP_BAR_ICON_SIZE
    icon.offset_bottom = TOP_BAR_ICON_SIZE
    icon.pivot_offset = Vector2(TOP_BAR_ICON_SIZE / 2.0, TOP_BAR_ICON_SIZE / 2.0)
func has_relic(id: String) -> bool:
    for relic_ui: RelicUI in relics.get_children():
        if relic_ui.relic.id == id and is_instance_valid(relic_ui):
            return true
    return false
    
func get_all_relics()  -> Array[Relic]:
    var relic_ui_nodes := _get_all_relic_ui_nodes()
    var relics_array: Array[Relic] = []
    
    for relic_ui: RelicUI in relic_ui_nodes:
        relics_array.append(relic_ui.relic)
        
    return relics_array
    
func _get_all_relic_ui_nodes() ->  Array[RelicUI]:
    var all_relics: Array[RelicUI] = []
    for relic_ui: RelicUI in relics.get_children():
        all_relics.append(relic_ui)
    
    return all_relics
    

func _on_relics_child_exiting_tree(relic_ui: RelicUI) -> void:
    print("child exiting tree: ", relic_ui.name)
    if not relic_ui:
        return
    
    if relic_ui.relic:
        relic_ui.relic.deactivate_relic(relic_ui)
        


# ============================================================================
# Acquisition beat - the relic flies from where you took it to its slot
# ============================================================================
#
# Gaining a relic used to be completely silent and completely still: add_relic() built the
# icon and the row simply had one more thing in it. RelicUI.flash() already existed but was
# only ever fired by hover, and reusing it here would have been the wrong call twice over -
# it would give acquiring and hovering the same vocabulary, and a 0.3s bump in the top-left
# corner is not where the player is looking. They are looking at the reward row or the shop
# stall they just clicked, in the middle of the screen.
#
# So the icon travels: it launches from the click, arcs up to its slot in the bar, and the
# slot answers with a punch, a ring and a sound. The point is the eye following it, which is
# also the cheapest way to teach a new player that the relic bar is where their relics live.
#
# OPT-IN, and that is the load-bearing part. add_relic() has six callers and only three of
# them are acquisitions (battle reward, shop purchase, the Dice Arcanist event). The other
# three are the starting relic at run start, the save-restore loop in run.gd, and add_relics()
# - announcing on those would pop every relic you own every time you load a run.

const NO_ORIGIN := Vector2.INF

# Above the top bar (3) so the icon is visible landing on the bar, below card inspect (99),
# tooltips (100) and the transition curtain (110) - a relic must not fly over a screen wipe.
const FLIGHT_LAYER := 95
const FLIGHT_TIME := 0.46
# Arc height, not a straight line: a relic sailing up and over reads as being carried home,
# where a straight slide reads as a UI element being repositioned.
const FLIGHT_ARC_HEIGHT := 90.0
const FLIGHT_START_SCALE := 1.7
# Below this the flight is a few frames long and reads as a glitch, so those callers get the
# arrival beat on its own instead. Also covers a source that resolves on top of the bar.
const FLIGHT_MIN_DISTANCE := 60.0

const ARRIVAL_PUNCH_SCALE := 1.55  # deliberately bigger than hover's 1.2 - see above
const ARRIVAL_PUNCH_TIME := 0.09
const ARRIVAL_SETTLE_TIME := 0.34
const ARRIVAL_FLASH_COLOR := Color(2.4, 2.2, 1.7)
const ARRIVAL_FLASH_IN := 0.05
const ARRIVAL_FLASH_OUT := 0.28
const ARRIVAL_RING_SIZE := 122.0
const ARRIVAL_RING_TIME := 0.44
const ARRIVAL_RING_COLOR := Color(1.0, 0.82, 0.38)

# PLACEHOLDER (project convention): usedrunesound.wav is an arcane-sounding chime that was
# sitting unused on disk - card_rewards.gd only ever mentions it in a comment as a candidate.
# Swap the file freely; relic acquisition had no sound at all before this.
const ARRIVAL_SFX := preload("res://sounds/usedrunesound.wav")
const ARRIVAL_SFX_PITCH := 1.06
const ARRIVAL_SFX_VOLUME_DB := -5.0


func _announce_relic(relic_ui: RelicUI, from_global: Vector2) -> void:
    # One frame, and it is not optional: relics is an HFlowContainer and containers sort
    # their children DEFERRED, so a slot added this frame still reports a stale (usually
    # zero) rect. Reading the flight's destination now would aim it at the wrong place.
    await get_tree().process_frame
    if not is_instance_valid(relic_ui) or not is_instance_valid(self):
        return

    var destination := relic_ui.get_global_rect().get_center()
    if from_global != NO_ORIGIN and from_global.distance_to(destination) > FLIGHT_MIN_DISTANCE:
        await _fly_relic_icon(relic_ui.relic.icon, from_global, destination)
        # The run can end (or the bar can be rebuilt) while the icon is in the air.
        if not is_instance_valid(relic_ui):
            return

    _play_arrival(relic_ui)


# The flying icon is a throwaway copy, never the real one: the real slot stays put and stays
# interactive the whole time, so nothing about the bar depends on this finishing.
func _fly_relic_icon(icon: Texture, from_global: Vector2, to_global: Vector2) -> void:
    # Parented to the handler rather than to the tree root so it dies with the run scene -
    # a flight layer under root would happily keep drawing over the main menu.
    var layer := CanvasLayer.new()
    layer.name = "RelicFlight"
    layer.layer = FLIGHT_LAYER
    add_child(layer)

    var icon_size := Vector2(TOP_BAR_ICON_SIZE, TOP_BAR_ICON_SIZE)
    var flyer := TextureRect.new()
    flyer.texture = icon
    # Matches relic_ui.tscn's Icon (expand_mode 1 / stretch_mode 6) so what flies looks
    # exactly like what lands.
    flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    flyer.custom_minimum_size = icon_size
    flyer.size = icon_size
    flyer.pivot_offset = icon_size * 0.5
    flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flyer.scale = Vector2.ONE * FLIGHT_START_SCALE
    layer.add_child(flyer)

    var half := icon_size * 0.5
    var control_point := from_global.lerp(to_global, 0.5) + Vector2(0.0, -FLIGHT_ARC_HEIGHT)
    flyer.position = from_global - half

    var tween := layer.create_tween()
    # Quadratic bezier, same shape language as the power orbs. EASE_IN so it accelerates
    # into the bar - it is being pulled home, not drifting there.
    tween.tween_method(
        func(t: float) -> void:
            if not is_instance_valid(flyer):
                return
            var a := from_global.lerp(control_point, t)
            var b := control_point.lerp(to_global, t)
            flyer.position = a.lerp(b, t) - half,
        0.0, 1.0, FLIGHT_TIME
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(flyer, "scale", Vector2.ONE, FLIGHT_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

    await tween.finished
    if is_instance_valid(layer):
        layer.queue_free()


func _play_arrival(relic_ui: RelicUI) -> void:
    var icon := relic_ui.get_node_or_null("Icon") as Control
    if icon == null:
        return

    # Icon already has a centred pivot from _resize_for_top_bar, so this punches from the
    # middle rather than growing out of its top-left corner.
    var punch := icon.create_tween()
    punch.tween_property(icon, "scale", Vector2.ONE * ARRIVAL_PUNCH_SCALE, ARRIVAL_PUNCH_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    punch.tween_property(icon, "scale", Vector2.ONE, ARRIVAL_SETTLE_TIME) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    # modulate, not the white flash material RelicUI.flash() swaps in: that material is the
    # hover animation's, and borrowing it would put the two beats back in the same language.
    # Safe because the Icon carries no material of its own (relic_ui.tscn leaves it null).
    var flash := icon.create_tween()
    flash.tween_property(icon, "modulate", ARRIVAL_FLASH_COLOR, ARRIVAL_FLASH_IN) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    flash.tween_property(icon, "modulate", Color.WHITE, ARRIVAL_FLASH_OUT) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

    _spawn_arrival_ring(relic_ui.get_global_rect().get_center())
    SFXPlayer.play(ARRIVAL_SFX, false, ARRIVAL_SFX_PITCH, ARRIVAL_SFX_VOLUME_DB)


# Expanding additive ring behind the slot. Additive so it can only add light and can never
# darken the icon it lands on, and it fades on its OWN shorter curve so it never holds a
# bright peak over the relic the player is trying to read.
func _spawn_arrival_ring(center: Vector2) -> void:
    var layer := CanvasLayer.new()
    layer.name = "RelicRing"
    layer.layer = FLIGHT_LAYER
    add_child(layer)

    var ring := TextureRect.new()
    ring.texture = _get_ring_texture()
    ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ring.custom_minimum_size = Vector2(ARRIVAL_RING_SIZE, ARRIVAL_RING_SIZE)
    ring.size = Vector2(ARRIVAL_RING_SIZE, ARRIVAL_RING_SIZE)
    ring.pivot_offset = ring.size * 0.5
    ring.position = center - ring.size * 0.5
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring.modulate = Color(ARRIVAL_RING_COLOR, 0.9)
    ring.scale = Vector2.ONE * 0.35
    var material := CanvasItemMaterial.new()
    material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    ring.material = material
    layer.add_child(ring)

    var grow := layer.create_tween()
    grow.tween_property(ring, "scale", Vector2.ONE, ARRIVAL_RING_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    var fade := layer.create_tween()
    fade.tween_property(ring, "modulate:a", 0.0, ARRIVAL_RING_TIME * 0.8) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    fade.tween_callback(layer.queue_free)


# Built once and shared - same soft radial recipe as the power orbs and the card-reward motes.
static var _ring_texture: GradientTexture2D


static func _get_ring_texture() -> GradientTexture2D:
    if _ring_texture != null:
        return _ring_texture
    var gradient := Gradient.new()
    # Hollow middle so it reads as a ring around the relic rather than a blob over it.
    gradient.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 1.0])
    gradient.colors = PackedColorArray([
        Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)
    ])
    _ring_texture = GradientTexture2D.new()
    _ring_texture.gradient = gradient
    _ring_texture.fill = GradientTexture2D.FILL_RADIAL
    _ring_texture.fill_from = Vector2(0.5, 0.5)
    _ring_texture.fill_to = Vector2(1.0, 0.5)
    _ring_texture.width = 128
    _ring_texture.height = 128
    return _ring_texture
