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

func add_relic(relic: Relic) -> void:
    if has_relic(relic.id):
        return
    var new_relic_ui := RELIC_UI.instantiate() as RelicUI
    _resize_for_top_bar(new_relic_ui)
    relics.add_child(new_relic_ui)
    new_relic_ui.relic = relic  # set_relic handles initialize_relic already
    print("ADDED: ", relic.id)
    AchievementManager.report_relic_count(relics.get_child_count())

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
        
