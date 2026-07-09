class_name RelicUI
extends Control

@export var relic: Relic : set = set_relic
@onready var icon: TextureRect = $Icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var counter: Label = $Counter
@export var initialize_on_set := true

const TOOLTIP_OFFSET_X = 2
const TOOLTIP_HEIGHT = 108
const TOOLTIP_SPACING = 1

const TooltipScene = preload("res://scenes/ui/tooltip.tscn")

var tooltip_instance: CanvasLayer
var tooltip_instances_tags: Array = []
var _hover_id := 0

func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func set_relic(new_relic: Relic) -> void:
    if not is_node_ready():
        await ready
    relic = new_relic
    icon.texture = relic.icon
    counter.visible = false
    if initialize_on_set:
        relic.initialize_relic(self)

func flash() -> void:
    animation_player.play("flash")

# Tooltip instances are added under get_tree().root (not this node), so they don't get freed
# automatically for free when RelicUI leaves the tree (e.g. exiting the shop while still
# hovering a relic - the RelicUI node is destroyed, but mouse_exited never gets a chance to
# fire, and the still-running _on_mouse_entered() coroutine gets silently cancelled along with
# it, so its own safety timeout below never even runs). This is the same "tooltip stuck
# forever" bug class as intent_ui.gd's, just surfacing on a scene transition instead of rapid
# re-hover - clean up explicitly whenever this node itself is removed from the tree.
func _exit_tree() -> void:
    _cleanup_tooltips()

func _cleanup_tooltips() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
    for tooltip in tooltip_instances_tags:
        if tooltip and is_instance_valid(tooltip):
            tooltip.queue_free()
    tooltip_instances_tags.clear()

func _on_mouse_entered() -> void:
    flash()
    _hover_id += 1
    var my_id := _hover_id

    _cleanup_tooltips()

    await get_tree().create_timer(0.5).timeout

    if my_id != _hover_id:
        return
    if not get_global_rect().has_point(get_global_mouse_position()):
        return
    if not relic:
        return

    # Tooltip principal de la relique (nom + description), au curseur
    tooltip_instance = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance)
    var tooltip_panel = tooltip_instance.get_node("Tooltip")
    tooltip_panel.tooltip_title.text = "[color=gold][b]%s[/b][/color]" % relic.relic_name
    tooltip_panel.tooltip_label.text = relic.get_colorized_description(relic.tooltip)
    var pos = get_global_mouse_position() + Vector2(24, 24)
    tooltip_panel.show_tooltip(pos)

    # Safety net (unlike the tag tooltips below, which already have their own 6s
    # timeout, this main tooltip previously had NONE) - mouse_exited/_exit_tree are
    # the only other cleanup paths, and neither fires if the tree gets paused
    # mid-hover (e.g. consulting the map), since GUI signals don't fire on a
    # paused non-ALWAYS node. Without this, a tooltip open right before a pause
    # would sit on screen forever, even after unpausing. Captures the instance
    # itself (not just the hover id) so a superseded tooltip still gets freed by
    # its own timer - same pattern as intent_ui.gd's _start_tooltip_safety_timeout.
    var this_main_tooltip := tooltip_instance
    get_tree().create_timer(8.0).timeout.connect(func():
        if not is_instance_valid(this_main_tooltip):
            return
        if tooltip_instance == this_main_tooltip:
            tooltip_instance = null
        this_main_tooltip.queue_free()
    )

    var tags_to_show := []
    if relic.tags != "":
        for tag in relic.tags.split(","):
            var trimmed: String = tag.strip_edges()
            if trimmed != "":
                tags_to_show.append(trimmed)

    # Dice-type mentions don't need an explicit tag (see KeywordColorizer.colorize()) - detect
    # them straight from the tooltip text so their tooltip still shows even on relics that were
    # never tagged with the dice type they mention (e.g. Dice Bag's `tags` field is empty).
    for dice_keyword in KeywordColorizer.find_dice_keywords_in_text(relic.tooltip):
        if not tags_to_show.has(dice_keyword):
            tags_to_show.append(dice_keyword)

    if tags_to_show.is_empty():
        return

    # Attendre une frame pour que le tooltip principal ait sa taille réelle
    await get_tree().create_timer(0.5).timeout
    if my_id != _hover_id:
        return

    var total_height = (tags_to_show.size() * TOOLTIP_HEIGHT) + ((tags_to_show.size() - 1) * TOOLTIP_SPACING)
    var center_y = pos.y + (tooltip_panel.size.y / 2.0)
    var start_y = center_y - (total_height / 2.0)

    var screen_height = get_viewport_rect().size.y
    if start_y + total_height > screen_height - 20:
        start_y = screen_height - total_height - 20
    if start_y < 20:
        start_y = 20

    # Décalé par rapport au bord droit du tooltip principal, pas de l'icône
    var base_pos = Vector2(pos.x + tooltip_panel.size.x + TOOLTIP_OFFSET_X, start_y)
    var captured_id := my_id

    for i in range(tags_to_show.size()):
        var tag_tooltip = TooltipScene.instantiate()
        get_tree().root.add_child(tag_tooltip)
        var tag_panel = tag_tooltip.get_node("Tooltip")
        tag_panel.get_tooltip_content(tags_to_show[i])
        var tag_pos = (base_pos + Vector2(0, i * (TOOLTIP_HEIGHT + TOOLTIP_SPACING))).round()
        tag_panel.show_tooltip(tag_pos)
        tooltip_instances_tags.append(tag_tooltip)

    get_tree().create_timer(6.0).timeout.connect(func():
        if captured_id == _hover_id:
            _cleanup_tooltips()
    )
    
func _on_mouse_exited() -> void:
    _hover_id += 1
    _cleanup_tooltips()
