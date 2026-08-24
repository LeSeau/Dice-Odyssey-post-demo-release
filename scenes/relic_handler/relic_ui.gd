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

# The tooltip's title box is a fixed-width RichTextLabel (default bold_font_size=16) that
# doesn't grow the panel to fit - a long relic name (e.g. "Cartographer's Quill") wraps and
# gets clipped by the box's fixed height instead of showing in full. Step the font size down
# past a couple length thresholds so it shrinks to fit on one line instead.
func _fit_tooltip_title(title_label: RichTextLabel, relic_name: String) -> void:
    if relic_name.length() > 20:
        title_label.add_theme_font_size_override("bold_font_size", 11)
    elif relic_name.length() > 15:
        title_label.add_theme_font_size_override("bold_font_size", 13)

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
    Global.add_tooltip(tooltip_instance, self)
    var tooltip_panel = tooltip_instance.get_node("Tooltip")
    tooltip_panel.tooltip_title.text = "[color=gold][b]%s[/b][/color]" % relic.relic_name
    _fit_tooltip_title(tooltip_panel.tooltip_title, relic.relic_name)
    tooltip_panel.tooltip_label.text = relic.get_colorized_description(relic.tooltip)
    # Same shared ordering the card hover uses, so a relic's sub-tooltips read in the order its
    # own text mentions them (tags used to come out in authored order, dice types in dict
    # order). Dice types and Power need no explicit tag - Dice Bag's `tags` is empty outright,
    # and Blood Sword / Metronome / Overflow Valve render the Power glyph while tagging nothing,
    # so before this they showed the icon with nothing to explain it.
    # Resolved here rather than after the panel is placed: this panel and its keyword column
    # are positioned as ONE group so a relic hovered near the right of the bar can't push its
    # column off screen - see Global.tooltip_group_x.
    var tags_to_show := KeywordColorizer.ordered_description_keywords(relic.tooltip, relic.tags)
    var group_width := Global.TOOLTIP_PANEL_SIZE.x
    if not tags_to_show.is_empty():
        group_width += TOOLTIP_OFFSET_X + Global.TOOLTIP_PANEL_SIZE.x
    var mouse_pos := get_global_mouse_position()
    var pos := Vector2(
        Global.tooltip_group_x(mouse_pos.x, 0.0, group_width, 24.0), mouse_pos.y + 24.0)
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

    if tags_to_show.is_empty():
        return

    # Attendre une frame pour que le tooltip principal ait sa taille réelle
    await get_tree().create_timer(0.5).timeout
    if my_id != _hover_id:
        return

    var start_y := Global.tooltip_column_y(pos.y + (tooltip_panel.size.y / 2.0),
        tags_to_show.size(), TOOLTIP_HEIGHT, TOOLTIP_SPACING)
    # Décalé par rapport au bord droit du tooltip principal, pas de l'icône - la place pour
    # cette colonne est déjà réservée par le placement de groupe ci-dessus.
    var base_pos := Vector2(pos.x + tooltip_panel.size.x + TOOLTIP_OFFSET_X, start_y)
    var captured_id := my_id

    for i in range(tags_to_show.size()):
        var tag_tooltip = TooltipScene.instantiate()
        Global.add_tooltip(tag_tooltip, self)
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
