class_name CardMenuUI
extends CenterContainer

# At the top of your CardUI class, add these constants:
const TOOLTIP_OFFSET_X = 20  # Horizontal distance from card
const TOOLTIP_HEIGHT = 108    # Approximate height of each tooltip
const TOOLTIP_SPACING = 1     # Space between tooltips
const BASE_STYLEBOX := preload("res://scenes/card_ui/card_ui_normal.tres")
const BASE_CELESTIAL_STYLEBOX := preload("res://scenes/card_ui/card_ui_celestial.tres")
const HOVER_STYLEBOX := preload("res://scenes/card_ui/card_menu_ui_hover_test.tres")
const SUPPORT_STYLEBOX := preload("res://scenes/card_ui/card_ui_normal_celestial.tres")
const NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none.tres")

const MIN_STYLEBOX := preload("res://scenes/card_ui/card_requirement_min.tres")
const MAX_STYLEBOX := preload("res://scenes/card_ui/card_requirement_max.tres")
const EVEN_STYLEBOX := preload("res://scenes/card_ui/card_requirement_even.tres")
const ODD_STYLEBOX := preload("res://scenes/card_ui/card_requirement_odd.tres")
const RED_STYLEBOX := preload("res://scenes/card_ui/card_requirement_red.tres")
const EXACT_STYLEBOX := preload("res://scenes/card_ui/card_requirement_exact.tres")
const MULTIPLE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_multiple.tres")

const BONUS_MIN_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_min.tres")
const BONUS_MAX_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_max.tres")
const BONUS_EVEN_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_even.tres")
const BONUS_ODD_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_odd.tres")
const BONUS_RED_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_red.tres")
const BONUS_EXACT_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_exact.tres")
const BONUS_MULTIPLE_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_multiple.tres")

const CELESTIAL_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner_celestial.tres")
const CELESTIAL_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_celestial.tres")
const CELESTIAL_REQUIREMENT_NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none_celestial.tres")
const CELESTIAL_ART_STYLEBOX := preload("res://scenes/card_ui/card_ui_celestial_art.tres")
const HOVER_CELESTIAL_STYLEBOX := preload("res://scenes/card_ui/card_ui_hover_celestial.tres")
const HOVER_BLESSING_STYLEBOX := preload("res://scenes/card_ui/card_ui_hover_blessing.tres")

# Explicit "normal card" values, matching what CardBanner/DescriptionPanel/Description already
# had baked into card_menu_ui.tscn as their default theme_override_* properties. That baked
# .tscn value IS the same per-node override storage add_theme_*_override()/remove_theme_*_
# override() manipulate at runtime (there's no separate "scene default" layer to fall back to)
# - so resetting a reused node to normal must re-apply these explicitly, not remove_*_override(),
# which would strip the .tscn value entirely and fall through to the generic theme default.
const NORMAL_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner.tres")
const NORMAL_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_normal.tres")
const NORMAL_DESC_OUTLINE_COLOR := Color(0.22554, 1.57929e-07, 0.0404674, 1)
# Description is now a RichTextLabel (converted so keyword colors from Card.get_colorized_
# description() can render), which has no `label_settings` property. This LabelSettings
# resource is kept preloaded anyway, purely as the source of truth for .outline_color below -
# it's the only property that actually differs between the normal and Celestial description
# styles; font/size/color/shadow are identical between the two, and now live as static theme
# overrides directly on the Description node in card_menu_ui.tscn instead.
const CELESTIAL_DESC_LABEL_SETTINGS := preload("res://scenes/card_ui/celestial_card_description_label.tres")

const BLESSING_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner_blessing.tres")
const BLESSING_STYLEBOX := preload("res://scenes/card_ui/card_ui_blessing.tres")
const BLESSING_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_blessing.tres")
const BLESSING_DESC_LABEL_SETTINGS := preload("res://scenes/card_ui/blessing_card_description_label.tres")

const REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_requirement_ribbon.tres")
const NO_REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_no_requirement_ribbon.tres")

# Shared across every CardUI/CardMenuUI instance via the .tscn (sub-resources aren't
# resource_local_to_scene by default) - never mutate this one directly, duplicate() it first
# (see _apply_title_color below), same pattern as MUSCLE_STATUS.duplicate() in bolster.gd.
const TITLE_LABEL_SETTINGS := preload("res://scenes/card_ui/card_title.tres")
const UPGRADED_TITLE_COLOR := Color(0.36, 0.85, 0.36)

const TooltipScene = preload("res://scenes/ui/tooltip.tscn")


@export var card: Card : set = set_card
# Opt-out for contexts showing this card purely as a static illustration (e.g. the Blessing
# tutorial popup's example card) - default false preserves hover tooltips everywhere else.
@export var disable_hover_tooltip: bool = false
# Opt-out for display-only instances (e.g. the before/after preview in the upgrade confirm
# dialog) so clicking them doesn't re-trigger the removing/upgrading click logic below.
@export var interactive: bool = true

@onready var card_frame: Panel = $Visuals/CardBackground/CardFrame
@onready var title: Label = $Visuals/CardBackground/CardFrame/CardBanner/Title
@onready var icon: TextureRect = $Visuals/CardBackground/CardFrame/Panel/CardArt
@onready var description: RichTextLabel = $Visuals/CardBackground/CardFrame/DescriptionPanel/DescriptionCenter/Description
@onready var requirement_panel: Panel = $Visuals/CardBackground/CardFrame/RequirementPanel
@onready var requirement_label: Label = $Visuals/CardBackground/CardFrame/RequirementPanel/RequirementLabel
@onready var bonus_effect: HBoxContainer = $Visuals/CardBackground/CardFrame/BonusEffect
@onready var bonus_requirement_panel: Panel = $Visuals/CardBackground/CardFrame/BonusEffect/BonusRequirementPanel
@onready var bonus_requirement_label: Label = $Visuals/CardBackground/CardFrame/BonusEffect/BonusRequirementPanel/BonusRequirementLabel
@onready var bonus_effect_texture: TextureRect = $Visuals/CardBackground/CardFrame/BonusEffect/BonusEffectTexture
@onready var bonus_effect_label: RichTextLabel = $Visuals/CardBackground/CardFrame/BonusEffect/BonusEffectLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var removal_sound_player: AudioStreamPlayer2D = $AnimationPlayer/RemovalSoundPlayer
@onready var description_panel: Panel = $Visuals/CardBackground/CardFrame/DescriptionPanel
@onready var card_banner: Panel = $Visuals/CardBackground/CardFrame/CardBanner
@onready var bonus_separator: ColorRect = $Visuals/CardBackground/CardFrame/BonusSeparator



func _on_visuals_mouse_entered() -> void:
    if card and card.can_play_without_dice:
        card_frame.set("theme_override_styles/panel", HOVER_CELESTIAL_STYLEBOX)
    elif card and card.type == Card.Type.BLESSING:
        card_frame.set("theme_override_styles/panel", HOVER_BLESSING_STYLEBOX)
    else:
        card_frame.set("theme_override_styles/panel", HOVER_STYLEBOX)

func _on_visuals_mouse_exited() -> void:
    if card and card.can_play_without_dice:
        card_frame.set("theme_override_styles/panel", BASE_CELESTIAL_STYLEBOX)
    elif card and card.type == Card.Type.BLESSING:
        card_frame.set("theme_override_styles/panel", BLESSING_STYLEBOX)
    else:
        card_frame.set("theme_override_styles/panel", BASE_STYLEBOX)



func set_card(value: Card) -> void:
    if not is_node_ready():
        await ready 
    card = value
    icon.texture = card.icon
    title.text = card.name
    _apply_title_color()
    _apply_description(card.description)
    requirement_label.label_settings = REQUIREMENT_LABEL_SETTINGS

    if card.requirement == Card.Requirement.NONE:
        requirement_panel.add_theme_stylebox_override("panel", NONE_STYLEBOX)
        requirement_label.label_settings = NO_REQUIREMENT_LABEL_SETTINGS
        requirement_label.text = "ANY"
    elif card.requirement == Card.Requirement.MAX:
        requirement_panel.add_theme_stylebox_override("panel", MAX_STYLEBOX)
        requirement_label.text = "Max %d" % card.requirement_number
    elif card.requirement == Card.Requirement.EVEN:
        requirement_panel.add_theme_stylebox_override("panel", EVEN_STYLEBOX)
        requirement_label.text = "Even"
    elif card.requirement == Card.Requirement.ODD:
        requirement_panel.add_theme_stylebox_override("panel", ODD_STYLEBOX)
        requirement_label.text = "Odd"
    elif card.requirement == Card.Requirement.RED:
        requirement_panel.add_theme_stylebox_override("panel", RED_STYLEBOX)
        requirement_label.text = "Red"
    elif card.requirement == Card.Requirement.EXACT:
        requirement_panel.add_theme_stylebox_override("panel", EXACT_STYLEBOX)
        requirement_label.text = "Exact %d" % card.requirement_number
    elif card.requirement == Card.Requirement.MIN:
        requirement_panel.add_theme_stylebox_override("panel", MIN_STYLEBOX)
        requirement_label.text = "Min %d" % card.requirement_number
    elif card.requirement == Card.Requirement.MULTIPLE:
        requirement_panel.add_theme_stylebox_override("panel", MULTIPLE_STYLEBOX)
        requirement_label.text = "Mult %d" % card.requirement_number
    # Celestial and Blessing each override CardFrame/CardBanner/DescriptionPanel/description
    # outline - reset to the plain-card look in the else branch, otherwise a CardMenuUI node
    # that's reused for multiple cards (e.g. the upgrade confirm dialog's before/after preview)
    # keeps showing the PREVIOUS card's Celestial/Blessing styling forever, since nothing else
    # in this file ever clears these overrides. Freshly-instantiated cards (shop/reward grids)
    # never had an override to begin with, so this is a no-op for them.
    if card.can_play_without_dice:
        description_panel.add_theme_stylebox_override("panel", CELESTIAL_DESC_STYLEBOX)
        card_banner.add_theme_stylebox_override("panel", CELESTIAL_BANNER_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", SUPPORT_STYLEBOX)
        requirement_panel.add_theme_stylebox_override("panel", CELESTIAL_REQUIREMENT_NONE_STYLEBOX)
        description.add_theme_color_override("font_outline_color", CELESTIAL_DESC_LABEL_SETTINGS.outline_color)
    elif card.type == Card.Type.BLESSING:
        card_banner.add_theme_stylebox_override("panel", BLESSING_BANNER_STYLEBOX)
        description_panel.add_theme_stylebox_override("panel", BLESSING_DESC_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", BLESSING_STYLEBOX)
        description.add_theme_color_override("font_outline_color", BLESSING_DESC_LABEL_SETTINGS.outline_color)
    else:
        description_panel.add_theme_stylebox_override("panel", NORMAL_DESC_STYLEBOX)
        card_banner.add_theme_stylebox_override("panel", NORMAL_BANNER_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", BASE_STYLEBOX)
        description.add_theme_color_override("font_outline_color", NORMAL_DESC_OUTLINE_COLOR)
    # Make sure to show the bonus_effect container if it has a requirement
    if card.bonus_requirement == Card.Requirement.NONE:
        bonus_effect.hide()
        bonus_separator.hide()
    else:
        # Important: Show the container if there is a bonus requirement
        bonus_effect.show()
        bonus_separator.show()
        bonus_effect_label.text = card.get_colorized_description(str(card.bonus_description_text))
        bonus_effect_texture.texture = card.bonus_description_icon
        if card.bonus_requirement == Card.Requirement.MAX:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_MAX_STYLEBOX)
            bonus_requirement_label.text = "Max %d" % card.bonus_requirement_number
        elif card.bonus_requirement == Card.Requirement.EVEN:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_EVEN_STYLEBOX)
            bonus_requirement_label.text = "Even"
        elif card.bonus_requirement == Card.Requirement.ODD:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_ODD_STYLEBOX)
            bonus_requirement_label.text = "Odd"
        elif card.bonus_requirement == Card.Requirement.RED:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_RED_STYLEBOX)
            bonus_requirement_label.text = "Red"
        elif card.bonus_requirement == Card.Requirement.EXACT:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_EXACT_STYLEBOX)
            bonus_requirement_label.text = "Exact %d" % card.bonus_requirement_number
        elif card.bonus_requirement == Card.Requirement.MIN:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_MIN_STYLEBOX)
            bonus_requirement_label.text = "Min %d" % card.bonus_requirement_number
        elif card.bonus_requirement == Card.Requirement.MULTIPLE:
            bonus_requirement_panel.add_theme_stylebox_override("panel", BONUS_MULTIPLE_STYLEBOX)
            bonus_requirement_label.text = "Mult %d" % card.bonus_requirement_number


# Green title on upgraded cards (STS2-style). Duplicates the shared LabelSettings only when
# needed so non-upgraded cards never touch (and can't accidentally tint) the shared resource.
func _apply_title_color() -> void:
    if card.upgraded:
        var upgraded_settings := TITLE_LABEL_SETTINGS.duplicate()
        upgraded_settings.font_color = UPGRADED_TITLE_COLOR
        title.label_settings = upgraded_settings
    else:
        title.label_settings = TITLE_LABEL_SETTINGS


# Single chokepoint for writing to the Description RichTextLabel: applies keyword coloring
# (Card.get_colorized_description(), driven off card.tags) and re-centers the text via BBCode,
# since RichTextLabel has no horizontal_alignment property the way Label did.
func _apply_description(text: String) -> void:
    description.text = "[center]%s[/center]" % card.get_colorized_description(text)


func _on_card_frame_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not interactive:
            return

        if Global.removing_card:
            animation_player.play("removal")
            removal_sound_player.play()
            # Wait for the animation to finish (optional: check the name)
            await animation_player.animation_finished

            Events.card_removed.emit(card)
            queue_free()
        elif Global.upgrading_card:
            Events.card_upgrade_requested.emit(card)



var tooltip_instance_requirement: Panel
var tooltip_instance_bonus: Panel
var tooltip_instances_tags: Array = []

# Replace your _on_card_frame_mouse_entered function:
var _card_hover_id := 0

func _on_card_frame_mouse_entered() -> void:
    if disable_hover_tooltip:
        return
    _card_hover_id += 1
    var my_id := _card_hover_id
    
    _cleanup_tooltips()
    
    await get_tree().create_timer(1.0).timeout
    
    if my_id != _card_hover_id:
        return
    if not is_mouse_over_card():
        return
    
    var tooltips_to_show = []
    
    var requirement_string = Card.Requirement.keys()[card.requirement]
    if requirement_string != "NONE":
        tooltips_to_show.append(requirement_string)
    
    var bonus_requirement_string = Card.Requirement.keys()[card.bonus_requirement]
    if bonus_requirement_string != "NONE":
        tooltips_to_show.append(bonus_requirement_string)

    if card.type == Card.Type.BLESSING:
        tooltips_to_show.append("Blessing")

    if card.tags != "":
        var tags_array = card.tags.split(",")
        for tag in tags_array:
            var trimmed_tag = tag.strip_edges()
            if trimmed_tag != "":
                tooltips_to_show.append(trimmed_tag)

    # Dice-type mentions don't need an explicit tag (see KeywordColorizer.colorize()) - detect
    # them straight from the description text so their tooltip still shows even on cards that
    # were never tagged with the dice type they mention.
    for dice_keyword in KeywordColorizer.find_dice_keywords_in_text(card.description):
        if not tooltips_to_show.has(dice_keyword):
            tooltips_to_show.append(dice_keyword)

    if tooltips_to_show.is_empty():
        return
    
    var total_tooltip_height = (tooltips_to_show.size() * TOOLTIP_HEIGHT) + ((tooltips_to_show.size() - 1) * TOOLTIP_SPACING)
    var card_center_y = global_position.y + (size.y / 2.0)
    var start_y = card_center_y - (total_tooltip_height / 2.0)
    
    var screen_height = get_viewport_rect().size.y
    var bottom_y = start_y + total_tooltip_height
    if bottom_y > screen_height - 20:
        start_y = screen_height - total_tooltip_height - 20
    if start_y < 20:
        start_y = 20
    
    var base_pos = Vector2(global_position.x + size.x + TOOLTIP_OFFSET_X, start_y)
    var captured_id := my_id
    
    for i in range(tooltips_to_show.size()):
        var tooltip = TooltipScene.instantiate()
        get_tree().root.add_child(tooltip)
        var tooltip_panel = tooltip.get_node("Tooltip")
        tooltip_panel.get_tooltip_content(tooltips_to_show[i])
        var tooltip_pos = base_pos + Vector2(0, i * (TOOLTIP_HEIGHT + TOOLTIP_SPACING))
        tooltip_panel.show_tooltip(tooltip_pos)
        tooltip_instances_tags.append(tooltip)
    
    get_tree().create_timer(6.0).timeout.connect(func():
        if captured_id == _card_hover_id:
            _cleanup_tooltips()
    )

func _on_card_frame_mouse_exited() -> void:
    _card_hover_id += 1
    _cleanup_tooltips()

func _cleanup_tooltips() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null
    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null
    for tooltip in tooltip_instances_tags:
        if tooltip and is_instance_valid(tooltip):
            tooltip.queue_free()
    tooltip_instances_tags.clear()


func is_mouse_over_card() -> bool:
    return get_global_rect().has_point(get_global_mouse_position())
