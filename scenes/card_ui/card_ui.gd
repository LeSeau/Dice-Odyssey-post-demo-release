class_name CardUI
extends Control

signal reparent_requested(which_card_ui: CardUI)
signal mouse_entered_card
signal mouse_exited_card

# At the top of your CardUI class, add these constants:
const TOOLTIP_OFFSET_X = 2  # Horizontal distance from card
const TOOLTIP_HEIGHT = 108    # Approximate height of each tooltip
const TOOLTIP_SPACING = 1     # Space between tooltips

enum PlayableGlow { NONE, AVAILABLE, HOT, NEUTRAL }

const DiceInterfaceScript := preload("res://scenes/dices/dice_interface.gd")
const GLOW_DEFAULT_COLOR := Color(0.184314, 0.917647, 0.843137)
const GLOW_BORDER_WIDTH_HOT := 5
const GLOW_BORDER_WIDTH_AVAILABLE := 3
const GLOW_SHADOW_ALPHA_HOT := 0.65
const GLOW_SHADOW_ALPHA_AVAILABLE := 0.35
const GLOW_SHADOW_SIZE_HOT := 7
const GLOW_SHADOW_SIZE_AVAILABLE := 4
const GLOW_HOT_MAX_ALPHA := 1.0
const GLOW_HOT_MIN_ALPHA := 0.35
const GLOW_AVAILABLE_ALPHA := 0.5
const GLOW_PULSE_DURATION := 1.1
# Dim unplayable cards by darkening (RGB multiply at full alpha) rather than
# reducing alpha. Alpha-dimming bleeds the background through and dims
# unevenly because the card is built from several stacked opaque layers;
# a full-alpha brightness multiply is uniform regardless of layer stacking.
# Two dim levels depending on WHY the card can't be played right now: a lighter dim when
# there's simply no power banked yet (roll_value <= 0, "haven't rolled"), and a darker dim
# when power IS banked but this specific card's requirement isn't met by it - the darker
# level reads as more "definitely no" than the lighter "not yet" state.
const UNPLAYABLE_MODULATE_NO_POWER := Color(0.75, 0.75, 0.75, 1.0)
const UNPLAYABLE_MODULATE_HAS_POWER := Color(0.6, 0.6, 0.6, 1.0)

# Shared across every CardUI/CardMenuUI instance via the .tscn (sub-resources aren't
# resource_local_to_scene by default) - never mutate this one directly, duplicate() it first
# (see set_upgraded_title_color below), same pattern as MUSCLE_STATUS.duplicate() in bolster.gd.
const TITLE_LABEL_SETTINGS := preload("res://scenes/card_ui/card_title.tres")
const UPGRADED_TITLE_COLOR := Color(0.36, 0.85, 0.36)

var current_glow_state: PlayableGlow = PlayableGlow.NONE

const TooltipScene = preload("res://scenes/ui/tooltip.tscn")
const SUPPORT_STYLEBOX := preload("res://scenes/card_ui/card_ui_normal_celestial.tres")

const BASE_STYLEBOX := preload("res://scenes/card_ui/card_ui_normal.tres")
const BASE_CELESTIAL_STYLEBOX := preload("res://scenes/card_ui/card_ui_celestial.tres")
const DRAG_STYLEBOX := preload("res://scenes/card_ui/card_drag_stylebox.tres")
const DRAG_CELESTIAL_STYLEBOX := preload("res://scenes/card_ui/card_drag_celestial_stylebox.tres")

const HOVER_STYLEBOX := preload("res://scenes/card_ui/card_ui_hover_test.tres")
const HOVER_CELESTIAL_STYLEBOX := preload("res://scenes/card_ui/card_ui_hover_test.tres")

const NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none.tres")
const MIN_STYLEBOX := preload("res://scenes/card_ui/card_requirement_min.tres")
const MAX_STYLEBOX := preload("res://scenes/card_ui/card_requirement_max.tres")
const EVEN_STYLEBOX := preload("res://scenes/card_ui/card_requirement_even.tres")
const ODD_STYLEBOX := preload("res://scenes/card_ui/card_requirement_odd.tres")
const RED_STYLEBOX := preload("res://scenes/card_ui/card_requirement_red.tres")
const EXACT_STYLEBOX := preload("res://scenes/card_ui/card_requirement_exact.tres")
const MULTIPLE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_multiple.tres")

const REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_requirement_ribbon.tres")
const NO_REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_no_requirement_ribbon.tres")

const BONUS_MIN_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_min.tres")
const BONUS_MAX_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_max.tres")
const BONUS_EVEN_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_even.tres")
const BONUS_ODD_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_odd.tres")
const BONUS_RED_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_red.tres")
const BONUS_EXACT_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_exact.tres")
const BONUS_MULTIPLE_STYLEBOX := preload("res://scenes/card_ui/card_bonus_requirement_multiple.tres")


const CELESTIAL_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner_celestial.tres")
const CELESTIAL_ART_STYLEBOX := preload("res://scenes/card_ui/card_ui_celestial_art.tres")
const CELESTIAL_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_celestial.tres")
const CELESTIAL_REQUIREMENT_NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none_celestial.tres")
# Description is now a RichTextLabel (converted so keyword colors from Card.get_colorized_
# description() can render), which has no `label_settings` property. This LabelSettings
# resource is kept preloaded anyway, purely as the source of truth for .outline_color below -
# it's the only property that actually differs between the normal and Celestial description
# styles; font/size/color/shadow are identical between the two, and now live as static theme
# overrides directly on the Description node in card_ui.tscn instead.
const CELESTIAL_DESC_LABEL_SETTINGS := preload("res://scenes/card_ui/celestial_card_description_label.tres")

const BLESSING_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner_blessing.tres")
const BLESSING_STYLEBOX := preload("res://scenes/card_ui/card_ui_blessing.tres")
const BLESSING_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_blessing.tres")
const BLESSING_DESC_LABEL_SETTINGS := preload("res://scenes/card_ui/blessing_card_description_label.tres")

@export var card: Card : set = _set_card
@export var char_stats: CharacterStats : set = _set_char_stats
@export var player_modifiers: ModifierHandler 

#@onready var panel: Panel = $Panel
#@onready var description: Label = $Description
#@onready var icon: TextureRect = $Icon


@onready var card_background: Panel = $CardBackground
@onready var panel: Panel = $CardBackground/CardFrame
@onready var card_banner: Panel = $CardBackground/CardFrame/CardBanner
@onready var title: Label = $CardBackground/CardFrame/CardBanner/Title

@onready var icon: TextureRect = $CardBackground/CardFrame/Panel/CardArt
@onready var description_panel: Panel = $CardBackground/CardFrame/DescriptionPanel

@onready var description: RichTextLabel = $CardBackground/CardFrame/DescriptionPanel/DescriptionCenter/Description

var _glow_tween: Tween
var _base_frame_stylebox: StyleBox
var _hot_frame_stylebox: StyleBoxFlat

@onready var requirement_panel: Panel = $CardBackground/CardFrame/RequirementPanel
@onready var requirement_label: Label = $CardBackground/CardFrame/RequirementPanel/RequirementLabel

@onready var bonus_effect: HBoxContainer = $CardBackground/CardFrame/BonusEffect
@onready var bonus_requirement_panel: Panel = $CardBackground/CardFrame/BonusEffect/BonusRequirementPanel
@onready var bonus_requirement_label: Label = $CardBackground/CardFrame/BonusEffect/BonusRequirementPanel/BonusRequirementLabel
@onready var bonus_effect_texture: TextureRect = $CardBackground/CardFrame/BonusEffect/BonusEffectTexture
@onready var bonus_effect_label: RichTextLabel = $CardBackground/CardFrame/BonusEffect/BonusEffectLabel
@onready var card_frame: Panel = $CardBackground/CardFrame
@onready var bonus_separator: ColorRect = $CardBackground/CardFrame/BonusSeparator


@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine
@onready var targets: Array[Node] = []

@onready var support_icon: TextureRect = $CardBackground/CardFrame/CardBanner/SupportIcon


var original_index := 0
var parent: Control
var tween: Tween
var playable := true : set = _set_playable
var disabled := false
var card_instance_id: int = 0



func _ready() -> void:
    #_setup_card_style()
    Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
    Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
    Events.card_drag_ended.connect(_on_card_drag_or_aim_ended)
    Events.card_aim_ended.connect(_on_card_drag_or_aim_ended)
    card_state_machine.init(self)
    Events.red_dice_rolled.connect(_on_red_dice_rolled)
    Events.red_dice_rolled.connect(_on_dice_rolled_update_description)
    Events.dice_rolled.connect(_on_dice_rolled_update_description)
    Events.dice_roll_reset.connect(_on_dice_rolled_update_description)
    Events.change_current_power.connect(_on_dice_rolled_update_description)
    if card:
        card_instance_id = card.instance_id
    



func _input(event: InputEvent) -> void:
    card_state_machine.on_input(event)


func animate_to_position(new_position: Vector2, duration: float) -> void:
    tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "global_position", new_position, duration)


func play() -> void:
    if not card:
        return
    # Record where the card was played from, so effects like refuel can launch their "dice
    # fly back to the die" visual from the card itself. Set before card.play() because that's
    # what fires the effect (and the refuel signal) synchronously.
    Global.last_played_card_position = global_position + size / 2.0
    card.play(targets, char_stats, player_modifiers)
    _fly_to_discard_and_free()


# Instead of vanishing instantly, the played card flies to the discard pile (Slay-the-Spire
# style) shrinking + spinning + fading on the way. The effect already fired above, so this
# is purely the visual send-off. By play() time the card lives on the ui_layer (the drag
# state reparented it there), so it can move freely above the hand.
#
# Single-targeted (aimed) cards and everything else take different paths, mirroring how the
# state machine itself already treats them differently (card_aiming_state.gd only runs for
# is_single_targeted() cards - everything else, including AoE attacks, never gets aimed and
# is released from wherever the drag happened to end, usually still near the hand):
#   - Single-targeted: unchanged - lifts from wherever it was released (near the enemy it was
#     aimed at) and arcs straight to discard. Julien confirmed this already reads well.
#   - Everything else (Block, support, AoE...): ALWAYS routes through a staging point near the
#     dice interface first, regardless of where it was actually released - like Slay the Spire
#     2, where non-attack cards visually resolve at the center before heading to discard.
func _fly_to_discard_and_free() -> void:
    set_process_input(false)  # stop routing input into the now-discarding state machine
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    disabled = true
    z_index = 100
    if tween and tween.is_valid():
        tween.kill()  # stop any in-progress positioning tween (e.g. the aim move-up) from fighting the fly

    var target_pos := global_position + Vector2(0, 220)  # fallback if discard pile not found
    var ui_layer := get_tree().get_first_node_in_group("ui_layer")
    if ui_layer:
        var discard: Node = ui_layer.get_node_or_null("DiscardPileButton")
        if discard and discard is Control:
            target_pos = (discard as Control).global_position

    var fly_tween := create_tween()
    var fade_delay: float

    if card.is_single_targeted():
        # Lift the card up first, then arc it down to the discard pile. Going straight from
        # the aim position (just above the hand) to the bottom-right pile looked flat/weird;
        # the little lift gives the toss an arc and reads like the card is "picked up" before
        # flying.
        var lift_pos := global_position + Vector2(0, -80)
        var lift_time := 0.16
        # Slower + floatier final leg to the discard pile (was 0.45s with an accelerating
        # TRANS_BACK/EASE_IN, read as "very fast" per Julien) - TRANS_SINE/EASE_IN_OUT drifts
        # rather than dashes.
        var arc_time := 0.7
        fly_tween.tween_property(self, "global_position", lift_pos, lift_time) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        fly_tween.tween_property(self, "global_position", target_pos, arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        fly_tween.parallel().tween_property(self, "scale", Vector2(0.15, 0.15), arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        fly_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-35.0, 35.0)), arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        fade_delay = lift_time + arc_time - 0.2  # fade in during the arc's last ~0.2s
    else:
        var stage_pos := global_position  # fallback if dice interface not found
        var dice_interface := get_tree().get_first_node_in_group("dice_interface")
        if dice_interface and dice_interface is Control:
            # Offset above the dice interface's own center - floating at dead-center (roughly
            # the ROLL button/power number) sat too low/cramped against the dice UI.
            stage_pos = (dice_interface as Control).get_global_rect().get_center() + Vector2(0, -140)

        var stage_time := 0.22
        var hold_time := 0.08
        # Slower + floatier final leg to the discard pile (was 0.4s with an accelerating
        # TRANS_BACK/EASE_IN) - TRANS_SINE/EASE_IN_OUT drifts rather than dashes.
        var arc_time := 0.65
        fly_tween.tween_property(self, "global_position", stage_pos, stage_time) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        fly_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-6.0, 6.0)), stage_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        fly_tween.tween_interval(hold_time)  # brief hold at the staging point before continuing on
        fly_tween.tween_property(self, "global_position", target_pos, arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        fly_tween.parallel().tween_property(self, "scale", Vector2(0.15, 0.15), arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        fly_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-35.0, 35.0)), arc_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        fade_delay = stage_time + hold_time + arc_time - 0.2

    # Fade out only near the END of the flight (separate tween), so the card stays visible
    # long enough to read that it's travelling to the discard pile - fading it across the
    # whole trip made the destination unclear. queue_free waits for the fade so it isn't cut.
    var fade_tween := create_tween()
    fade_tween.tween_interval(fade_delay)
    fade_tween.tween_property(self, "modulate:a", 0.0, 0.2) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fade_tween.tween_callback(queue_free)

# In your CardUI class:
func apply_fan_rotation(angle: float) -> void:
    # Apply rotation to the card
    #rotation_degrees = angle
    print("test rotation")
    


func _on_gui_input(event: InputEvent) -> void:
    card_state_machine.on_gui_input(event)


func _on_mouse_entered() -> void:
    card_state_machine.on_mouse_entered()
    emit_signal("mouse_entered_card")


func _on_mouse_exited() -> void:
    card_state_machine.on_mouse_exited()
    emit_signal("mouse_exited_card")



func _set_card(value: Card) -> void:
    if not is_node_ready():
        await ready

    card = value
    _apply_description(str(card.description))
    icon.texture = card.icon
    title.text = str(card.name)
    _apply_title_color()
    requirement_label.label_settings = REQUIREMENT_LABEL_SETTINGS
    #support_icon.visible = card.rarity == Card.Rarity.SUPPORT


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
    if card.type == Card.Type.BLESSING:
        card_banner.add_theme_stylebox_override("panel", BLESSING_BANNER_STYLEBOX)
        description_panel.add_theme_stylebox_override("panel", BLESSING_DESC_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", BLESSING_STYLEBOX)
        # Resync the glow cache same as the Celestial branch below - otherwise the first
        # playable-glow pass caches whatever stylebox was on CardFrame before this override
        # ran, and set_playable_visual() would keep re-applying that stale look at rest.
        _base_frame_stylebox = BLESSING_STYLEBOX
        _hot_frame_stylebox = null
        description.add_theme_color_override("font_outline_color", BLESSING_DESC_LABEL_SETTINGS.outline_color)

    if card.can_play_without_dice:

        description_panel.add_theme_stylebox_override("panel", CELESTIAL_DESC_STYLEBOX)
        card_banner.add_theme_stylebox_override("panel", CELESTIAL_BANNER_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", SUPPORT_STYLEBOX)
        # Keep the playable-glow cache in sync: set_playable_visual() lazily caches
        # whatever CardFrame's stylebox was on first call, which can happen before
        # this celestial override runs and would otherwise permanently re-apply the
        # stale maroon base every time the card returns to its resting glow state.
        _base_frame_stylebox = SUPPORT_STYLEBOX
        _hot_frame_stylebox = null
        requirement_panel.add_theme_stylebox_override("panel", CELESTIAL_REQUIREMENT_NONE_STYLEBOX)
        description.add_theme_color_override("font_outline_color", CELESTIAL_DESC_LABEL_SETTINGS.outline_color)
    # Fixed bonus requirement logic
    if card.bonus_requirement == Card.Requirement.NONE:
        bonus_effect.hide()
        bonus_separator.hide()
    else:
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


func _set_playable(value: bool) -> void:
    playable = value
    if not playable:
        description.add_theme_color_override("default_color", Color.RED)
        icon.modulate = Color(1, 1, 1, 0.5)
    else:
        description.remove_theme_color_override("default_color")
        icon.modulate = Color(1, 1, 1, 1)
        


func _set_char_stats(value: CharacterStats) -> void:
    char_stats = value
    char_stats.stats_changed.connect(_on_char_stats_changed)


func _on_drop_point_detector_area_entered(area: Area2D) -> void:
    if not targets.has(area):
        targets.append(area)


func _on_drop_point_detector_area_exited(area: Area2D) -> void:
    targets.erase(area)


func _on_card_drag_or_aiming_started(used_card: CardUI) -> void:
    if used_card == self:
        return
    
    disabled = true


func _on_card_drag_or_aim_ended(_card: CardUI) -> void:
    disabled = false
    self.playable = char_stats.can_play_card(card)


func _on_char_stats_changed() -> void:
    self.playable = char_stats.can_play_card(card)

func _on_red_dice_rolled() -> void:
    # Check if this specific card instance is the charged card
    if card.instance_id == Global.charged_card_instance_id:
        Global.dice_type = "red"
        if card.target == Card.Target.SINGLE_ENEMY:
            print("single enemy card")
            # Force staying in AIMING state if no target selected
            card_state_machine._on_transition_requested(
                card_state_machine.current_state, 
                CardState.State.AIMING
            )
        else:
            print("Playing specific charged card: ", card.id)
            card.play(targets, char_stats, player_modifiers)
            queue_free()
        
        Events.dice_rolled.emit(Global.dice_type, Global.roll_value)
        #Global.roll_value=0
        

    
   
    
func _setup_card_style() -> void:
    # Setup Card Background
    var bg_style = StyleBoxFlat.new()
    bg_style.bg_color = Color("#2A2040")  # Deep indigo background
    bg_style.corner_radius_top_left = 5
    bg_style.corner_radius_top_right = 5
    bg_style.corner_radius_bottom_left = 5
    bg_style.corner_radius_bottom_right = 5
    card_background.add_theme_stylebox_override("panel", bg_style)
    
    # Setup Card Frame
    var frame_style = StyleBoxFlat.new()
    frame_style.bg_color = Color("#2A2040")  # Same as background
    frame_style.border_color = Color("#D4AF37")  # Gold border
    frame_style.border_width_left = 2
    frame_style.border_width_top = 2
    frame_style.border_width_right = 2
    frame_style.border_width_bottom = 2
    frame_style.corner_radius_top_left = 5
    frame_style.corner_radius_top_right = 5
    frame_style.corner_radius_bottom_left = 5
    frame_style.corner_radius_bottom_right = 5
    panel.add_theme_stylebox_override("panel", frame_style)
    
    # Setup Card Banner
    var banner_style = StyleBoxFlat.new()
    banner_style.bg_color = Color("#4A2B7E")  # Royal purple
    banner_style.corner_radius_top_left = 5
    banner_style.corner_radius_top_right = 5
    card_banner.add_theme_stylebox_override("panel", banner_style)
    
    # Setup Card Title
    title.add_theme_color_override("font_color", Color("#FFD700"))  # Gold text
    title.add_theme_font_size_override("font_size", 14)
    
    # Setup Image Panel (assuming $CardBackground/CardFrame/Panel is the parent of CardArt)
    var image_panel = $CardBackground/CardFrame/Panel
    var image_style = StyleBoxFlat.new()
    image_style.bg_color = Color("#000000")  # Black background for image
    image_style.border_color = Color("#A67C00")  # Darker gold for inner frame
    image_style.border_width_left = 2
    image_style.border_width_top = 2
    image_style.border_width_right = 2
    image_style.border_width_bottom = 2
    image_panel.add_theme_stylebox_override("panel", image_style)
    
    # Setup Description
    var desc_style = StyleBoxFlat.new()
    desc_style.bg_color = Color("#F5F0DC")  # Parchment color
    desc_style.corner_radius_bottom_left = 5
    desc_style.corner_radius_bottom_right = 5
    # Assuming description is a Label inside a Panel, if it's just a Label:
    description.add_theme_color_override("font_color", Color("#3A2921"))  # Dark brown
    description.add_theme_font_size_override("font_size", 10)
    
    # Apply hover effects by updating your existing hover states
    # This uses your existing preloaded styleboxes but you can modify them
    # or create them programmatically like above


var tooltip_instance_requirement: Panel
var tooltip_instance_bonus: Panel
var tooltip_instances_tags: Array = []

# At the top of your CardUI, add these variables:
var _card_hover_id := 0

# Replace your _on_card_frame_mouse_entered:
func _on_card_frame_mouse_entered() -> void:
    # Invalidate any previous pending coroutine
    _card_hover_id += 1
    var my_id := _card_hover_id
    
    # Clean up any lingering tooltips immediately on new hover
    _cleanup_card_tooltips()
    
    await get_tree().create_timer(1.0).timeout
    
    # Bail if a newer hover started, or mouse already left
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
    
    # Capture hover_id for the lifetime timer closure below
    var captured_id := my_id
    
    for i in range(tooltips_to_show.size()):
        var tooltip = TooltipScene.instantiate()
        get_tree().root.add_child(tooltip)
        var tooltip_panel = tooltip.get_node("Tooltip")
        tooltip_panel.get_tooltip_content(tooltips_to_show[i])
        
        var tooltip_pos = base_pos + Vector2(0, i * (TOOLTIP_HEIGHT + TOOLTIP_SPACING))
        tooltip_pos = tooltip_pos.round()
        tooltip_panel.show_tooltip(tooltip_pos)
        
        tooltip_instances_tags.append(tooltip)
    
    # Safety net: auto-destroy after 6 seconds even if mouse_exited never fires
    get_tree().create_timer(6.0).timeout.connect(func():
        # Only clean up if this is still the active hover session
        if captured_id == _card_hover_id:
            _cleanup_card_tooltips()
    )

# Replace your _on_card_frame_mouse_exited:
func _on_card_frame_mouse_exited() -> void:
    _card_hover_id += 1  # Invalidate any pending coroutine
    _cleanup_card_tooltips()

# Add this helper to centralize all tooltip cleanup:
func _cleanup_card_tooltips() -> void:
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

# Add a function to set playability visual
func set_playable_visual(state: PlayableGlow) -> void:
    if not _base_frame_stylebox:
        _base_frame_stylebox = card_frame.get_theme_stylebox("panel")
    current_glow_state = state
    match state:
        PlayableGlow.HOT, PlayableGlow.AVAILABLE:
            modulate = Color.WHITE
            var is_hot := state == PlayableGlow.HOT
            if not _hot_frame_stylebox:
                _hot_frame_stylebox = _base_frame_stylebox.duplicate()
            var border_width := GLOW_BORDER_WIDTH_HOT if is_hot else GLOW_BORDER_WIDTH_AVAILABLE
            _hot_frame_stylebox.border_width_left = border_width
            _hot_frame_stylebox.border_width_top = border_width
            _hot_frame_stylebox.border_width_right = border_width
            _hot_frame_stylebox.border_width_bottom = border_width
            # Keep expand_margin >= border_width so the thicker glow border only
            # bleeds outward past the card's edge instead of intruding inward into
            # the rect, where it would get painted over by RequirementPanel /
            # DescriptionPanel / BonusEffect (siblings drawn on top of CardFrame).
            _hot_frame_stylebox.expand_margin_left = border_width
            _hot_frame_stylebox.expand_margin_top = border_width
            _hot_frame_stylebox.expand_margin_right = border_width
            _hot_frame_stylebox.expand_margin_bottom = border_width
            _hot_frame_stylebox.shadow_size = GLOW_SHADOW_SIZE_HOT if is_hot else GLOW_SHADOW_SIZE_AVAILABLE
            var dice_color: Color = DiceInterfaceScript.DICE_TYPE_COLOR.get(Global.dice_type, GLOW_DEFAULT_COLOR)
            _hot_frame_stylebox.shadow_color = Color(dice_color.r, dice_color.g, dice_color.b, GLOW_SHADOW_ALPHA_HOT if is_hot else GLOW_SHADOW_ALPHA_AVAILABLE)
            card_frame.add_theme_stylebox_override("panel", _hot_frame_stylebox)
            if is_hot:
                var current_alpha: float = _hot_frame_stylebox.border_color.a if (_glow_tween and _glow_tween.is_valid()) else GLOW_HOT_MIN_ALPHA
                _hot_frame_stylebox.border_color = Color(dice_color.r, dice_color.g, dice_color.b, current_alpha)
                if not (_glow_tween and _glow_tween.is_valid()):
                    _hot_frame_stylebox.border_color.a = GLOW_HOT_MIN_ALPHA
                    _glow_tween = create_tween().set_loops()
                    _glow_tween.tween_property(_hot_frame_stylebox, "border_color:a", GLOW_HOT_MAX_ALPHA, GLOW_PULSE_DURATION).set_trans(Tween.TRANS_SINE)
                    _glow_tween.tween_property(_hot_frame_stylebox, "border_color:a", GLOW_HOT_MIN_ALPHA, GLOW_PULSE_DURATION).set_trans(Tween.TRANS_SINE)
            else:
                if _glow_tween and _glow_tween.is_valid():
                    _glow_tween.kill()
                _hot_frame_stylebox.border_color = Color(dice_color.r, dice_color.g, dice_color.b, GLOW_AVAILABLE_ALPHA)
        PlayableGlow.NONE:
            if _glow_tween and _glow_tween.is_valid():
                _glow_tween.kill()
            card_frame.add_theme_stylebox_override("panel", _base_frame_stylebox)
            modulate = UNPLAYABLE_MODULATE_HAS_POWER if Global.roll_value > 0 else UNPLAYABLE_MODULATE_NO_POWER
        PlayableGlow.NEUTRAL:
            # Used while Inked: we can't tell if a card is playable (power is hidden), and
            # dimming it like a genuinely-blocked card is misleading since it's still playable.
            # Full brightness, no glow border - just the card's plain undecorated look.
            if _glow_tween and _glow_tween.is_valid():
                _glow_tween.kill()
            card_frame.add_theme_stylebox_override("panel", _base_frame_stylebox)
            modulate = Color.WHITE

# Re-applies whatever glow state was last set. Needed because other systems
# (e.g. card hover) can overwrite CardFrame's stylebox override directly.
func reapply_playable_visual() -> void:
    set_playable_visual(current_glow_state)

func _on_dice_rolled_update_description(_a = null, _b = null) -> void:
    if card and card.has_method("get_dynamic_description"):
        _apply_description(card.get_dynamic_description(player_modifiers))


# Single chokepoint for writing to the Description RichTextLabel: applies keyword coloring
# (Card.get_colorized_description(), driven off card.tags) and re-centers the text via BBCode,
# since RichTextLabel has no horizontal_alignment property the way Label did.
func _apply_description(text: String) -> void:
    description.text = "[center]%s[/center]" % card.get_colorized_description(text)
