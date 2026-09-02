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
const BLESSING_REQUIREMENT_NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none_blessing.tres")
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

# --- Omen: cards an enemy forced into your deck -----------------------------------------
# Cold ash body with a DULL IRON border. Normal, Blessing and Celestial cards all share the
# same gold border, so dropping gold is the loudest mark available for "this one is not
# yours", and it is one of the few that survives the hand fan (cards overlap at separation
# -35, so only the left ~105px and the banner are ever read).
# Measured and rejected: treating the ART. Desaturating it reads as the game already-spent
# "you cannot play this" dim (UNPLAYABLE_MODULATE_*), and on hex.png it collapses to a black
# rectangle outright, because that art carries its read in chroma rather than luminance. The
# art is therefore left completely untouched and the chrome carries the whole identity.
const OMEN_BANNER_STYLEBOX := preload("res://scenes/card_ui/card_banner_omen.tres")
const OMEN_STYLEBOX := preload("res://scenes/card_ui/card_ui_omen.tres")
const OMEN_DESC_STYLEBOX := preload("res://scenes/card_ui/card_ui_description_panel_omen.tres")
const OMEN_DESC_LABEL_SETTINGS := preload("res://scenes/card_ui/omen_card_description_label.tres")
const OMEN_REQUIREMENT_NONE_STYLEBOX := preload("res://scenes/card_ui/card_requirement_none_omen.tres")
const OMEN_NO_REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_no_requirement_ribbon_omen.tres")
const OMEN_TITLE_COLOR := Color(0.729412, 0.74902, 0.705882)
const OMEN_TITLE_OUTLINE_COLOR := Color(0.086275, 0.090196, 0.086275)
const HOVER_OMEN_STYLEBOX := preload("res://scenes/card_ui/card_ui_hover_omen.tres")

# Rarity gem in the banner's right slot - kept in sync with CardUI's copy of the same
# constants/logic. Every tier shows a gem, Common included (muted stone gray) - and since the
# texture is unconditionally overwritten on every set_card(), the reused BeforeCard/AfterCard
# nodes in the upgrade confirm dialog can't leak a previous card's gem (the bug class the old
# Uncommon/Rare-only version needed an explicit else-branch for).
const RARITY_GEM_TEXTURES := {
    Card.RarityTier.COMMON: preload("res://assets/images/rarity_gem_common.png"),
    Card.RarityTier.UNCOMMON: preload("res://assets/images/rarity_gem_uncommon.png"),
    Card.RarityTier.RARE: preload("res://assets/images/rarity_gem_rare.png"),
}

const REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_requirement_ribbon.tres")
const NO_REQUIREMENT_LABEL_SETTINGS := preload("res://scenes/card_ui/card_ui_no_requirement_ribbon.tres")

# Shared across every CardUI/CardMenuUI instance via the .tscn (sub-resources aren't
# resource_local_to_scene by default) - never mutate this one directly, duplicate() it first
# (see _apply_title_color below), same pattern as MUSCLE_STATUS.duplicate() in bolster.gd.
const TITLE_LABEL_SETTINGS := preload("res://scenes/card_ui/card_title.tres")
const UPGRADED_TITLE_COLOR := Color(0.36, 0.85, 0.36)

# Width available to the Title label between its symmetric banner insets (see the Title node's
# offset_left/offset_right in the .tscn) - reserves the rarity gem's slot on the right,
# mirrored left so the title stays optically centered. Kept in sync with CardUI's copy.
const TITLE_MAX_WIDTH := 104.0
# Descending candidates - first size whose MEASURED width fits is used. Char-count thresholds
# (the previous approach) can't work: caps width varies too much per glyph ("Necromancy+" is
# 11 chars but wider than several 13-char names).
const TITLE_FONT_SIZE_CANDIDATES: Array[int] = [15, 12, 10, 9]

# Long descriptions overflow the fixed-height DescriptionPanel at the default 12pt. Descending
# candidates - the first size whose MEASURED wrapped height fits the panel wins. Character counts
# (the previous approach) failed here for the same reason they failed for titles: they ignore
# per-glyph width, and they ignore the inline Power glyph the colorizer injects, which costs ~a
# word of width but ZERO characters. Crescendo (59 chars, one under the old 60-char threshold)
# stayed at 12pt and spilled a 4th line out of the panel. 9 and 8 are unreached safety nets since
# the panel grew (see DESC_PANEL_HEIGHT); the worst card in the pool, All In+, now lands at 10.
const DESC_FONT_SIZE_CANDIDATES: Array[int] = [12, 11, 10, 9, 8]

# DescriptionPanel is an INVISIBLE layout box: its stylebox bg_color is byte-identical to the card
# body's on the Celestial and Blessing variants, and differs by ~0.001 on the normal one (compare
# card_ui_description_panel_*.tres against card_ui_*.tres). So its height can grow into the 22px of
# dead space below it - y188..210, which only the BonusEffect row ever occupies - with zero visual
# change, buying long descriptions 1-2 font steps instead of making them pay for the side margins.
# 56 rather than the full 66: the text is vertically centred in the panel, so an over-tall panel
# lets a big block drift down until it crowds the card's bottom border. Cards WITH a bonus effect
# keep 44 (BonusSeparator sits at y188). Kept in sync with CardUI's copy of these constants.
const DESC_PANEL_TOP := 144.0
const DESC_PANEL_HEIGHT := 56.0
const DESC_PANEL_HEIGHT_WITH_BONUS := 44.0


static func title_font_size_for(text: String) -> int:
    var font: Font = TITLE_LABEL_SETTINGS.font
    for size: int in TITLE_FONT_SIZE_CANDIDATES:
        if font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x <= TITLE_MAX_WIDTH:
            return size
    return TITLE_FONT_SIZE_CANDIDATES[-1]


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
@onready var rarity_gem: TextureRect = $Visuals/CardBackground/CardFrame/CardBanner/RarityGem



func _on_visuals_mouse_entered() -> void:
    if card and card.type == Card.Type.OMEN:
        card_frame.set("theme_override_styles/panel", HOVER_OMEN_STYLEBOX)
    elif card and card.can_play_without_dice:
        card_frame.set("theme_override_styles/panel", HOVER_CELESTIAL_STYLEBOX)
    elif card and card.type == Card.Type.BLESSING:
        card_frame.set("theme_override_styles/panel", HOVER_BLESSING_STYLEBOX)
    else:
        card_frame.set("theme_override_styles/panel", HOVER_STYLEBOX)

func _on_visuals_mouse_exited() -> void:
    if card and card.type == Card.Type.OMEN:
        card_frame.set("theme_override_styles/panel", OMEN_STYLEBOX)
    elif card and card.can_play_without_dice:
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
    _resize_description_panel()
    _apply_description(card.description)
    requirement_label.label_settings = REQUIREMENT_LABEL_SETTINGS
    rarity_gem.texture = RARITY_GEM_TEXTURES[card.rarity_tier]

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
    # Omen first: junk is Celestial, so without this it falls into the Celestial branch
    # below and gets painted teal like a premium card.
    if card.type == Card.Type.OMEN:
        card_banner.add_theme_stylebox_override("panel", OMEN_BANNER_STYLEBOX)
        description_panel.add_theme_stylebox_override("panel", OMEN_DESC_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", OMEN_STYLEBOX)
        if card.requirement == Card.Requirement.NONE:
            requirement_panel.add_theme_stylebox_override("panel", OMEN_REQUIREMENT_NONE_STYLEBOX)
            requirement_label.label_settings = OMEN_NO_REQUIREMENT_LABEL_SETTINGS
        description.add_theme_color_override("font_outline_color", OMEN_DESC_LABEL_SETTINGS.outline_color)
    elif card.can_play_without_dice:
        description_panel.add_theme_stylebox_override("panel", CELESTIAL_DESC_STYLEBOX)
        card_banner.add_theme_stylebox_override("panel", CELESTIAL_BANNER_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", SUPPORT_STYLEBOX)
        # Only force the "no requirement" ribbon look when there truly is no requirement -
        # a Celestial card that DOES have a real requirement (e.g. From Nothing's Exact 0)
        # keeps its requirement-specific stylebox instead of being silently overwritten.
        if card.requirement == Card.Requirement.NONE:
            requirement_panel.add_theme_stylebox_override("panel", CELESTIAL_REQUIREMENT_NONE_STYLEBOX)
        description.add_theme_color_override("font_outline_color", CELESTIAL_DESC_LABEL_SETTINGS.outline_color)
    elif card.type == Card.Type.BLESSING:
        card_banner.add_theme_stylebox_override("panel", BLESSING_BANNER_STYLEBOX)
        description_panel.add_theme_stylebox_override("panel", BLESSING_DESC_STYLEBOX)
        card_frame.add_theme_stylebox_override("panel", BLESSING_STYLEBOX)
        # Same as the Celestial branch: only re-style the "ANY" ribbon when there's truly no
        # requirement, so a Blessing WITH a real requirement (e.g. Berserk's Min 6) keeps its
        # requirement-specific ribbon. Without this, a requirement-less Blessing falls through
        # with the plain red NONE_STYLEBOX ribbon instead of matching its plum card body.
        if card.requirement == Card.Requirement.NONE:
            requirement_panel.add_theme_stylebox_override("panel", BLESSING_REQUIREMENT_NONE_STYLEBOX)
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
        bonus_effect_label.text = card.get_colorized_description(str(card.bonus_description_text), 12)
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


# Green title on upgraded cards (STS2-style), plus a length-based font size step-down so long
# names stay on 1 line. Always duplicates the shared LabelSettings now that font_size can also
# vary per-card - mutating the shared resource in place would leak one card's size onto every
# other card using it (same trap as the color-only version this replaced).
func _apply_title_color() -> void:
    var settings := TITLE_LABEL_SETTINGS.duplicate()
    settings.font_size = title_font_size_for(card.name)
    # Omen wins over upgraded: the type identity has to survive whatever else the card is.
    # The title is the single most-read mark in the fan (the banner band is never covered by
    # the neighbouring card), so an ash title is what actually sells "not yours" at a glance.
    # This MUST go through the duplicated LabelSettings - a Label carrying one ignores
    # add_theme_color_override("font_color", ...) entirely, and silently.
    if card.type == Card.Type.OMEN:
        settings.font_color = OMEN_TITLE_COLOR
        settings.outline_color = OMEN_TITLE_OUTLINE_COLOR
    elif card.upgraded:
        settings.font_color = UPGRADED_TITLE_COLOR
    title.label_settings = settings


# Single chokepoint for writing to the Description RichTextLabel: applies keyword coloring
# (Card.get_colorized_description(), driven off card.tags), re-centers the text via BBCode
# (RichTextLabel has no horizontal_alignment property the way Label did), and steps the font
# size down for long text so it doesn't overflow the fixed-height DescriptionPanel.
# Cards without a BonusEffect row reclaim the dead space below the panel (see DESC_PANEL_HEIGHT).
# Call before _apply_description: that measures against description_panel.size.y. Unconditional on
# both branches - these nodes are reused (the upgrade dialog's Before/AfterCard), so a bonus-effect
# card must be able to shrink the panel back, not just grow it.
func _resize_description_panel() -> void:
    var h := DESC_PANEL_HEIGHT_WITH_BONUS if card.bonus_requirement != Card.Requirement.NONE \
        else DESC_PANEL_HEIGHT
    description_panel.offset_top = DESC_PANEL_TOP
    description_panel.offset_bottom = DESC_PANEL_TOP + h


func _apply_description(text: String) -> void:
    # Measured against the panel's real height rather than a char-count guess: the colorizer's
    # inline Power glyph and per-glyph width both move the wrap without moving the length.
    var available := description_panel.size.y
    for desc_font_size: int in DESC_FONT_SIZE_CANDIDATES:
        description.add_theme_font_size_override("normal_font_size", desc_font_size)
        # Power glyph rides 2px above the font size so it reads at cap height on every step-down.
        description.text = "[center]%s[/center]" % card.get_colorized_description(text, desc_font_size + 2)
        # RichTextLabel validates its wrap inside get_content_height(), so this reads true in the
        # same frame - no await needed (and none wanted: this is a hot path on the deck screen).
        if description.get_content_height() <= available:
            return


# Public swap used by the inspect overlay's upgrade toggle / paging. set_card() alone would
# leave the previous card's hover tooltip column standing over the new one, and because the
# cursor never leaves the frame during a swap, mouse_entered can't fire again to rebuild it -
# so hand the hover back explicitly, the same way _on_rarity_gem_mouse_exited already does.
func display_card(value: Card) -> void:
    clear_hover_tooltips()
    set_card(value)
    if not disable_hover_tooltip and card and is_mouse_over_card():
        _on_card_frame_mouse_entered()


func clear_hover_tooltips() -> void:
    _card_hover_id += 1
    _gem_hover_id += 1
    _cleanup_tooltips()
    _cleanup_gem_tooltip()


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

# Rarity gem hover tooltip - menu contexts only (rewards, deck view, shop). The in-hand
# CardUI gem is deliberately inert (mouse_filter IGNORE in card_ui.tscn); here the gem is
# mouse_filter PASS so it can receive hover while clicks still propagate up to the card's
# own gui_input (reward pick / remove / upgrade).
const RARITY_TOOLTIP_KEYWORDS := {
    Card.RarityTier.COMMON: "Common",
    Card.RarityTier.UNCOMMON: "Uncommon",
    Card.RarityTier.RARE: "Rare",
}
var _gem_tooltip: Node = null
var _gem_hover_id := 0


# The gem lives INSIDE the card frame, so the cursor being on it still satisfies
# is_mouse_over_card() - and because the gem is mouse_filter PASS, the frame's own hover
# fires too. Left alone, hovering the gem stacked the rarity tooltip on top of the card's
# entire requirement/keyword/Power tower. The rule is: while the cursor is on the gem, the
# gem owns the hover and is the ONLY tooltip shown.
func _is_mouse_over_gem() -> bool:
    return rarity_gem != null and rarity_gem.visible \
        and rarity_gem.get_global_rect().has_point(get_global_mouse_position())


func _on_rarity_gem_mouse_entered() -> void:
    if disable_hover_tooltip or not card:
        return
    # Take the hover from the card: kill any visible stack, and invalidate the pending
    # card-hover coroutine so a tower queued before the cursor reached the gem can't land
    # after it (the frame's 1s delay is longer than the flick from card body to gem).
    _card_hover_id += 1
    _cleanup_tooltips()

    _gem_hover_id += 1
    var captured_id := _gem_hover_id
    _cleanup_gem_tooltip()

    _gem_tooltip = TooltipScene.instantiate()
    Global.add_tooltip(_gem_tooltip, self)
    var tooltip_panel = _gem_tooltip.get_node("Tooltip")
    tooltip_panel.get_tooltip_content(RARITY_TOOLTIP_KEYWORDS[card.rarity_tier])

    # Just right of the gem, clamped so the rightmost reward card's tooltip stays on screen.
    var pos := rarity_gem.get_global_rect().end + Vector2(8.0, -20.0)
    var viewport_size := get_viewport_rect().size
    pos.x = minf(pos.x, viewport_size.x - 220.0)
    pos.y = clampf(pos.y, 10.0, viewport_size.y - 120.0)
    tooltip_panel.show_tooltip(pos.round())

    # Same leak safety net as every other root-parented tooltip in this file.
    get_tree().create_timer(6.0).timeout.connect(func():
        if captured_id == _gem_hover_id:
            _cleanup_gem_tooltip()
    )


func _on_rarity_gem_mouse_exited() -> void:
    _gem_hover_id += 1
    _cleanup_gem_tooltip()
    # Sliding off the gem back onto the card body: the frame's mouse_entered will NOT fire
    # again (the cursor never left the frame), so hand the hover back explicitly - otherwise
    # the card would sit there tooltip-less until the player left and re-entered it.
    if not disable_hover_tooltip and card and is_mouse_over_card():
        _on_card_frame_mouse_entered()


func _cleanup_gem_tooltip() -> void:
    if _gem_tooltip and is_instance_valid(_gem_tooltip):
        _gem_tooltip.queue_free()
    _gem_tooltip = null

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
    # Cursor settled on the gem during the delay - the gem's tooltip owns this hover.
    if _is_mouse_over_gem():
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

    if card.type == Card.Type.OMEN:
        tooltips_to_show.append("Omen")

    # Omen cards are Celestial so the player can always bin them, but leading with "needs no
    # Dice or Power to play" frames an enemy gift as a perk. The Omen tooltip already carries
    # the only part that matters here, which is that playing it is how you get rid of it.
    if card.can_play_without_dice and card.type != Card.Type.OMEN:
        tooltips_to_show.append("Celestial")

    # Tags, dice types mentioned in the text, and Power - all ordered by where they read in the
    # description, so the stack follows the sentence under the requirement ribbon. Shared with
    # card_ui.gd so the two views can't drift (see KeywordColorizer for why each source is
    # included; neither dice types nor Power need an explicit tag).
    for keyword in KeywordColorizer.ordered_description_keywords(
            card.description, card.tags, str(card.bonus_description_text)):
        if not tooltips_to_show.has(keyword):
            tooltips_to_show.append(keyword)

    if tooltips_to_show.is_empty():
        return
    
    # Anchor off get_global_rect(), which carries scale (measured: a 140x210 card at scale 2.4
    # reports 336x504), NOT off `size`, which does not. Mixing the two put the column one
    # unscaled card-width from the left edge - i.e. on top of a magnified card. Every other
    # consumer draws at scale 1, where the two agree; the inspect overlay is the first that
    # magnifies one.
    var card_rect := get_global_rect()
    var start_y := Global.tooltip_column_y(card_rect.get_center().y,
        tooltips_to_show.size(), TOOLTIP_HEIGHT, TOOLTIP_SPACING)
    # Flips to the card's left when there's no room on its right (a card in the deck view's
    # rightmost columns used to push this stack ~70px off screen). Flipping rather than
    # clamping matters here: a clamped column would sit on top of the card being read.
    var base_pos := Vector2(
        Global.tooltip_group_x(card_rect.position.x, card_rect.size.x,
            Global.TOOLTIP_PANEL_SIZE.x, TOOLTIP_OFFSET_X),
        start_y)
    var captured_id := my_id
    
    for i in range(tooltips_to_show.size()):
        var tooltip = TooltipScene.instantiate()
        Global.add_tooltip(tooltip, self)
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


# Tooltips live under get_tree().root, not this node - free them explicitly when this card
# is torn down (e.g. picking a reward frees the whole screen while the gem/frame is still
# hovered, so mouse_exited never fires - the documented root-parented-tooltip leak pattern).
func _exit_tree() -> void:
    _cleanup_tooltips()
    _cleanup_gem_tooltip()


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
