class_name TutorialOverlay
extends CanvasLayer

## Reusable affordance kit for the combat tutorial (tutorial_redesign_2026-07.md §5) -
## TutorialDirector drives it entirely through this small set of methods, it owns no
## tutorial-specific knowledge of its own. Lives on a high layer (see .tscn) so it renders
## above every other CanvasLayer in battle.tscn, including the victory screen.

signal continue_pressed
signal skip_pressed

enum Dim { NONE, SOFT, FULL }
enum PointerDir { DOWN, UP, LEFT, RIGHT }

const DIM_ALPHA := {Dim.NONE: 0.0, Dim.SOFT: 0.4, Dim.FULL: 0.72}
const POINTER_GAP := 8.0
const POINTER_BOB_DISTANCE := 10.0
const POINTER_BOB_TIME := 0.4

# Text panel zones (1280x720 design canvas, matching every other absolute layout in
# battle.tscn). Each zone is a horizontal slot (x, w) plus a vertical BAND (y0..y1) with an
# attachment rule for where the panel sits inside the band. The panel's HEIGHT is computed
# from the actual text every time (see set_text) - fixed-height zones were tried first and
# always looked wrong: dead space under one-liners, clipping on paragraphs. Bands are laid
# out around the battle landmarks: top bar ends ~y88, dice interface x514-674 / y214-286,
# active die x521-665 / y294-438 (ROLL under it), hand cards start ~y581, End Turn bottom
# right ~x1063+. "speaker": true draws a small tail off the panel's bottom edge (see
# set_text/_position_bubble_tail) so the box reads as the player character talking rather
# than a floating caption - only "near_dice" sits over the character, so it's the only zone
# that opts in.
const TEXT_ZONES := {
    "center": {"x": 320.0, "w": 640.0, "y0": 170.0, "y1": 500.0, "attach": "center", "fit": true},
    "top": {"x": 280.0, "w": 720.0, "y0": 100.0, "y1": 280.0, "attach": "top"},
    # Card-instruction band. Three constraints squeeze it, and they nearly meet:
    #  - its bottom must clear the tutorial-lifted card, which now rises far enough to show a
    #    WHOLE card (hand.gd TUTORIAL_LIFT) - card top lands near y485, hence y1=458;
    #  - these boxes grow UPWARD from that bottom, and above them sits the Power number
    #    (ink ends ~y378) which the card steps are usually talking about, so they must not
    #    climb past ~y380;
    #  - that leaves ~75px, which is why the band is WIDE (800): a two-line box fits, a
    #    three-line one does not. Long instructions must wrap to 2 lines, so width buys height.
    "above_hand": {"x": 240.0, "w": 800.0, "y0": 290.0, "y1": 458.0, "attach": "bottom", "fit": true},
    # near_dice is BOTTOM-attached (was center): the speech-bubble tail hangs off the box's
    # bottom edge, so a bottom-anchored box keeps that edge - and thus the tail - at a fixed
    # height no matter how tall the text is. y1 raised (335 -> 310) so the box clears the
    # hero's idle-animation bob (Julien: "hero moves a bit, box not high enough for him").
    "near_dice": {
        "x": 90.0, "w": 420.0, "y0": 120.0, "y1": 310.0, "attach": "bottom",
        "speaker": true, "fit": true},
    "near_enemy": {"x": 690.0, "w": 420.0, "y0": 300.0, "y1": 566.0, "attach": "bottom", "fit": true},
    # Sits clear to the RIGHT of the Power number (glyph box ends ~x744) with room for a
    # LEFT-pointing arrow in between, so the box, the arrow and the digit read as one unit
    # instead of the box floating somewhere else on screen.
    "right_of_power": {"x": 850.0, "w": 396.0, "y0": 300.0, "y1": 470.0, "attach": "center"},
}

# Shared with PulseFrame's border (StyleBoxFlat_pulse in the .tscn) - keeps the "look here"
# glow and the "click here" pulse frame reading as the same visual language.
const GLOW_COLOR_GOLD := Color(0.788235, 0.635294, 0.152941, 1.0)
const GLOW_COLOR_THREAT := Color(0.85, 0.25, 0.2, 1.0)

# Kept deliberately small + gentle: an early pass sized the glow at max(w,h)*2.2 with a 0.85
# additive peak, which read as a giant screen-washing blob (Julien: "insanely intense & big").
# A soft additive halo just barely bigger than the target, peaking low, is the whole ask -
# "highlight the power, nothing extravagant".
const GLOW_DIAMETER_CAP := 100.0
const GLOW_SIZE_FACTOR := 0.9
const GLOW_SIZE_PAD := 16.0
const GLOW_ALPHA_PEAK := 0.32
const GLOW_ALPHA_LOW := 0.14

# Masks are plain black by default. The welcome card passes a warm tint instead, so the
# screen behind it reads as candlelit rather than switched-off - a neutral black dim under
# a bordered box is exactly the "system dialog" look the welcome beat is trying not to be.
const DIM_TINT_NEUTRAL := Color(0, 0, 0)
const DIM_TINT_WARM := Color(0.055, 0.028, 0.018)

const BUBBLE_BORDER_COLOR := Color(0.788235, 0.635294, 0.152941, 1.0)
const BUBBLE_FILL_COLOR := Color(0.058, 0.05, 0.09, 0.95)
# The near_dice speaker box floats above the player character (bottom-left of the battle).
# The tail is a small notch off the box's bottom edge, placed at this design-space x (roughly
# above the character's head) and pointing down at it - NOT at the box's own far-left corner,
# where a first pass wrongly anchored it (Julien: "great tail but off-position").
const SPEAKER_HEAD_X := 240.0
const SPEAKER_TAIL_HALF_W := 15.0
const SPEAKER_TAIL_HEIGHT := 22.0
const SPEAKER_TAIL_BORDER := 3.0

const PANEL_PAD_X := 18.0
const PANEL_PAD_Y := 14.0
const CONTINUE_SIZE := Vector2(112, 34)
const CONTINUE_GAP := 10.0

# Zones flagged "fit" pick their own width instead of always using the zone's full width.
# Reason: a one-line instruction stretched across a fixed 800px zone is a letterbox strip,
# which Julien kept flagging as "ugly rectangle" - the box needs to be shaped by its text, not
# by the slot it lives in. Widths are scanned and scored against a target width:height ratio;
# the zone's own w is now a MAXIMUM, and its band height is the hard ceiling.
const FIT_TARGET_ASPECT := 3.4
const FIT_MIN_W := 220.0
const FIT_STEP := 20.0

const ARROW_TEXTURES := {
    PointerDir.DOWN: preload("res://tutorial_arrow_down.png"),
    PointerDir.UP: preload("res://tutorial_arrow.png"),
}

# ---- Welcome card (show_welcome) -------------------------------------------------------
# The very first thing a new player ever sees. It deliberately does NOT reuse the generic
# step box (dark navy fill + hairline gold border + body-font "title" + stock Godot button),
# which reads as a system warning - it gets a title-card treatment instead: warm ember fill,
# decorative gold title, ornamental divider, warm halo, and a staged entrance. Sized/laid out
# exactly like set_text (fixed width, height derived from the shaped body text) so editing the
# copy can never clip or leave dead space.
const WELCOME_W := 664.0
const WELCOME_CENTER_Y := 336.0
const WELCOME_PAD_X := 36.0
const WELCOME_PAD_TOP := 26.0
const WELCOME_PAD_BOTTOM := 26.0
const WELCOME_TITLE_H := 46.0
const WELCOME_TITLE_RISE := 10.0
const WELCOME_DIVIDER_TOP_GAP := 6.0
const WELCOME_DIVIDER_H := 14.0
const WELCOME_DIAMOND := 11.0
const WELCOME_RULE_H := 2.0
const WELCOME_RULE_GAP := 16.0
const WELCOME_BODY_TOP_GAP := 16.0
const WELCOME_BUTTON_TOP_GAP := 24.0
const WELCOME_BUTTON_SIZE := Vector2(196, 46)

# Hugs the card rather than filling the room: a first pass at 1.9x/0.30 visibly re-lit the
# whole background, which fought the dim it sits on and cost the card its focus.
const WELCOME_GLOW_COLOR := Color(1.0, 0.72, 0.33)
const WELCOME_GLOW_SCALE := 1.6
const WELCOME_GLOW_ALPHA_PEAK := 0.25
const WELCOME_GLOW_ALPHA_LOW := 0.14

const WELCOME_MOTE_INTERVAL := 0.34
const WELCOME_MOTE_COLOR := Color(1.0, 0.82, 0.45)

var top_mask: ColorRect
var bottom_mask: ColorRect
var left_mask: ColorRect
var right_mask: ColorRect
var pulse_frame: Panel
var pointer_arrow: TextureRect
var text_panel: Panel
var label: RichTextLabel
var continue_button: Button
var skip_button: Button
var glow: TextureRect
var info_arrow: TextureRect
var info_panel: Panel
var info_label: RichTextLabel
var bubble_tail_border: Polygon2D
var bubble_tail_fill: Polygon2D

var welcome_root: Control
var welcome_glow: TextureRect
var welcome_panel: Panel
var welcome_title: Label
var welcome_divider: Control
var welcome_rule_left: TextureRect
var welcome_rule_right: TextureRect
var welcome_diamond: ColorRect
var welcome_body: RichTextLabel
var welcome_button: Button

var _pulse_tween: Tween
var _bob_tween: Tween
var _info_bob_tween: Tween
var _glow_tween: Tween
var _glow_texture: GradientTexture2D

var _welcome_tween: Tween
var _welcome_glow_tween: Tween
var _welcome_mote_timer: Timer
var _welcome_motes: Array[TextureRect] = []
var _welcome_title_text := ""
var _welcome_body_text := ""
var _welcome_active := false

var _masks: Array[ColorRect]
var _is_setup := false

# Last set_text() arguments - re-applied in _ready(). This node gets its first step content
# pushed while still waiting on its deferred add_child (see setup()'s comment), i.e. before
# it's in the tree; text shaping there relies on the label's override fonts alone. Re-running
# the layout once actually live settles any theme-dependent metric on its real value.
var _last_text := ""
var _last_zone := "center"
var _last_continue := false


func _ready() -> void:
    if not _is_setup:
        return
    # The welcome card is pushed while this node is still waiting on its deferred add_child,
    # i.e. out of the tree - where create_tween() isn't allowed at all. show_welcome() lands
    # on the final static frame in that case; the entrance actually plays here, the first
    # moment the node is live (and therefore the first moment anything is on screen anyway).
    if _welcome_active:
        _layout_welcome()
        _play_welcome_entrance()
    elif _last_text != "" and text_panel.visible:
        set_text(_last_text, _last_zone, _last_continue)


# Resolves every node ref and does the one-time hookup - called EXPLICITLY by
# TutorialDirector right after instantiate(), before add_child(). Deliberately NOT done in
# _ready(): TutorialDirector adds this scene from inside its OWN _ready(), and battle_started
# (which drives the tutorial's very first step) fires from run.gd shortly after in the same
# synchronous chain - well before Godot flushes a freshly-added child's deferred _ready()
# (confirmed by two separate null-onready-field crashes at runtime: one in start(), one in
# clear_all() from the first _advance()). get_node() on a just-instantiated PackedScene works
# immediately regardless of tree membership, so resolving refs manually here sidesteps the
# ready-timing question entirely instead of racing it.
func setup() -> void:
    if _is_setup:
        return
    _is_setup = true

    top_mask = $TopMask
    bottom_mask = $BottomMask
    left_mask = $LeftMask
    right_mask = $RightMask
    pulse_frame = $PulseFrame
    pointer_arrow = $PointerArrow
    text_panel = $TextPanel
    label = $TextPanel/Label
    continue_button = $TextPanel/ContinueButton
    skip_button = $SkipButton

    welcome_root = $WelcomeRoot
    welcome_glow = $WelcomeRoot/Glow
    welcome_panel = $WelcomeRoot/Panel
    welcome_title = $WelcomeRoot/Panel/Title
    welcome_divider = $WelcomeRoot/Panel/Divider
    welcome_rule_left = $WelcomeRoot/Panel/Divider/RuleLeft
    welcome_rule_right = $WelcomeRoot/Panel/Divider/RuleRight
    welcome_diamond = $WelcomeRoot/Panel/Divider/Diamond
    welcome_body = $WelcomeRoot/Panel/Body
    welcome_button = $WelcomeRoot/Panel/ContinueButton
    welcome_root.hide()
    welcome_body.scroll_active = false
    # Same signal as the generic box's Continue, so a step waiting on continue_pressed works
    # identically whichever presentation it used.
    welcome_button.pressed.connect(func(): continue_pressed.emit())

    _welcome_mote_timer = Timer.new()
    _welcome_mote_timer.wait_time = WELCOME_MOTE_INTERVAL
    _welcome_mote_timer.timeout.connect(_spawn_welcome_mote)
    add_child(_welcome_mote_timer)

    _masks = [top_mask, bottom_mask, left_mask, right_mask]
    for m in _masks:
        m.mouse_filter = Control.MOUSE_FILTER_IGNORE
        m.hide()
    pulse_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pulse_frame.hide()
    pointer_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pointer_arrow.hide()
    text_panel.hide()
    text_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.scroll_active = false
    label.bbcode_enabled = true
    continue_button.pressed.connect(func(): continue_pressed.emit())
    continue_button.hide()
    skip_button.pressed.connect(func(): skip_pressed.emit())
    skip_button.hide()

    # Built in code rather than the .tscn - a soft additive glow (see show_glow) and a two-
    # triangle speech-bubble tail (see _position_bubble_tail), neither of which need editor
    # authoring. Added last so both draw on top of the masks/pulse frame/text panel already
    # in the scene.
    glow = TextureRect.new()
    glow.texture = _get_glow_texture()
    glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var glow_mat := CanvasItemMaterial.new()
    glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    glow.material = glow_mat
    glow.hide()
    add_child(glow)

    # Second arrow, for pointing at an INFORMATIONAL target (the Power number, a Relic) while
    # the main pointer_arrow is busy on the step's action target (ROLL, a card, the enemy).
    info_arrow = TextureRect.new()
    info_arrow.texture = ARROW_TEXTURES[PointerDir.DOWN]
    info_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    info_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    info_arrow.size = Vector2(64, 86)  # matches PointerArrow's authored box in the .tscn
    info_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    info_arrow.hide()
    add_child(info_arrow)

    # Small standalone annotation box (see show_info_note) - a compact caption pinned next to
    # an info target like the Power number, separate from the main hero-speech box. Reuses the
    # main panel's stylebox + label fonts at a smaller size so it reads as the same UI family.
    info_panel = Panel.new()
    info_panel.add_theme_stylebox_override("panel", text_panel.get_theme_stylebox("panel"))
    info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    info_panel.hide()
    add_child(info_panel)
    info_label = RichTextLabel.new()
    info_label.bbcode_enabled = true
    info_label.scroll_active = false
    info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    info_label.add_theme_font_override("normal_font", label.get_theme_font("normal_font"))
    info_label.add_theme_font_override("bold_font", label.get_theme_font("bold_font"))
    info_label.add_theme_font_size_override("normal_font_size", 14)
    info_label.add_theme_font_size_override("bold_font_size", 15)
    info_panel.add_child(info_label)

    bubble_tail_border = Polygon2D.new()
    bubble_tail_border.color = BUBBLE_BORDER_COLOR
    bubble_tail_fill = Polygon2D.new()
    bubble_tail_fill.color = BUBBLE_FILL_COLOR
    add_child(bubble_tail_border)
    add_child(bubble_tail_fill)
    bubble_tail_border.hide()
    bubble_tail_fill.hide()


# Fixed design canvas (project.godot: viewport 1280x720, stretch mode "canvas_items" -
# every other absolute-coordinate UI element in this project, including TEXT_ZONES above,
# is authored against this same fixed space). Deliberately NOT get_viewport().get_visible_
# rect().size: this node is added to the tree from inside TutorialDirector's own _ready(),
# while Battle itself is still mid-entering the tree - get_node()/property sets on already-
# resolved refs work fine at that point (pure structural/local operations), but
# get_viewport() needs genuine live tree membership, which is deferred and doesn't flush
# until real idle time, well after the tutorial's first step already needs a spotlight.
const DESIGN_CANVAS_SIZE := Vector2(1280, 720)

func _screen_size() -> Vector2:
    return DESIGN_CANVAS_SIZE


# ---------------------------------------------------------------- Dim + spotlight

func set_dim(mode: Dim, tint: Color = DIM_TINT_NEUTRAL) -> void:
    var a: float = DIM_ALPHA.get(mode, 0.0)
    for m in _masks:
        m.color = Color(tint.r, tint.g, tint.b, a)
    if mode == Dim.NONE:
        for m in _masks:
            m.hide()
    else:
        clear_spotlight()


# Frames a rectangular "hole" over target_rect with 4 plain rects rather than a shader -
# simpler and lower-risk than authoring/maintaining a mask shader for one feature.
func set_spotlight(target_rect: Rect2, padding: float = 6.0) -> void:
    var rect := target_rect.grow(padding)
    var screen := _screen_size()

    top_mask.position = Vector2.ZERO
    top_mask.size = Vector2(screen.x, maxf(0.0, rect.position.y))

    bottom_mask.position = Vector2(0, rect.position.y + rect.size.y)
    bottom_mask.size = Vector2(screen.x, maxf(0.0, screen.y - bottom_mask.position.y))

    left_mask.position = Vector2(0, rect.position.y)
    left_mask.size = Vector2(maxf(0.0, rect.position.x), rect.size.y)

    right_mask.position = Vector2(rect.position.x + rect.size.x, rect.position.y)
    right_mask.size = Vector2(maxf(0.0, screen.x - right_mask.position.x), rect.size.y)

    for m in _masks:
        m.show()


func clear_spotlight() -> void:
    var screen := _screen_size()
    top_mask.position = Vector2.ZERO
    top_mask.size = screen
    top_mask.show()
    for m in [bottom_mask, left_mask, right_mask]:
        m.size = Vector2.ZERO
        m.hide()


# ---------------------------------------------------------------- Pointer arrow

func show_pointer(target_point: Vector2, direction: PointerDir = PointerDir.DOWN) -> void:
    # Always use the DOWN texture and flip/rotate it - the standalone "up" art
    # (tutorial_arrow.png) doesn't actually point straight up, so deriving every direction
    # from the known-good down arrow guarantees the orientation (the relic arrow was pointing
    # sideways). Godot 2D rotation is clockwise on screen, so a down-pointing arrow rotated by
    # +90 deg points LEFT and by -90 deg points RIGHT.
    pointer_arrow.texture = ARROW_TEXTURES[PointerDir.DOWN]
    pointer_arrow.flip_v = direction == PointerDir.UP
    pointer_arrow.pivot_offset = pointer_arrow.size / 2.0
    var half := pointer_arrow.size / 2.0
    # Rotation happens about pivot_offset, so the arrow's visual CENTRE stays at
    # position + half whatever the angle - place by centre, then convert back to position.
    # Along the pointing axis the tip is half.y away from that centre.
    var reach := half.y + POINTER_GAP
    var bob_axis := Vector2(0, -1)
    match direction:
        PointerDir.DOWN:  # tip points down - sits ABOVE the target
            pointer_arrow.rotation = 0.0
            pointer_arrow.position = target_point - Vector2(half.x, pointer_arrow.size.y + POINTER_GAP)
        PointerDir.UP:  # tip points up - sits BELOW the target
            pointer_arrow.rotation = 0.0
            pointer_arrow.position = target_point - Vector2(half.x, -POINTER_GAP)
            bob_axis = Vector2(0, 1)
        PointerDir.RIGHT:  # tip points right - sits LEFT of the target
            pointer_arrow.rotation = -PI / 2.0
            pointer_arrow.position = target_point - Vector2(reach, 0) - half
            bob_axis = Vector2(1, 0)
        PointerDir.LEFT:  # tip points left - sits RIGHT of the target
            pointer_arrow.rotation = PI / 2.0
            pointer_arrow.position = target_point + Vector2(reach, 0) - half
            bob_axis = Vector2(-1, 0)
    pointer_arrow.show()
    _restart_bob_tween(bob_axis)


func hide_pointer() -> void:
    pointer_arrow.hide()
    if _bob_tween and _bob_tween.is_valid():
        _bob_tween.kill()


func nudge_pointer() -> void:
    if not pointer_arrow.visible:
        return
    var tw := create_tween()
    tw.tween_property(pointer_arrow, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(pointer_arrow, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Bobs along the axis the arrow points, so a horizontal pointer nudges toward its target
# instead of drifting up and down beside it.
func _restart_bob_tween(axis: Vector2) -> void:
    if _bob_tween and _bob_tween.is_valid():
        _bob_tween.kill()
    var base := pointer_arrow.position
    _bob_tween = create_tween().set_loops()
    _bob_tween.tween_property(pointer_arrow, "position", base + axis * POINTER_BOB_DISTANCE, POINTER_BOB_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.tween_property(pointer_arrow, "position", base, POINTER_BOB_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Second, informational arrow (see info_arrow). Always points DOWN, sitting above target_point.
# STATIC by default - when it shares the screen with the bobbing action pointer, Julien wanted
# it to sit still so it reads as a label rather than a "do something here" prompt. Steps where
# it's the ONLY arrow pass animated=true, since there's nothing for it to be confused with and
# a still arrow just gets lost.
func show_info_pointer(target_point: Vector2, animated: bool = false) -> void:
    info_arrow.position = target_point - Vector2(info_arrow.size.x / 2.0, info_arrow.size.y + POINTER_GAP)
    info_arrow.show()
    if _info_bob_tween and _info_bob_tween.is_valid():
        _info_bob_tween.kill()
    if not animated:
        return
    var base_y := info_arrow.position.y
    _info_bob_tween = create_tween().set_loops()
    _info_bob_tween.tween_property(info_arrow, "position:y", base_y - POINTER_BOB_DISTANCE, POINTER_BOB_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _info_bob_tween.tween_property(info_arrow, "position:y", base_y, POINTER_BOB_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func hide_info_pointer() -> void:
    info_arrow.hide()
    if _info_bob_tween and _info_bob_tween.is_valid():
        _info_bob_tween.kill()


const INFO_NOTE_W := 224.0
const INFO_NOTE_PAD := 12.0

# Small caption placed to the RIGHT of anchor_rect (the space above/around the Power number is
# cramped by the dice panel/slots; the open ground toward the enemy isn't). Auto-heights to its
# text the same width-first way as set_text.
func show_info_note(text: String, anchor_rect: Rect2) -> void:
    var inner_w := INFO_NOTE_W - INFO_NOTE_PAD * 2.0
    info_label.position = Vector2(INFO_NOTE_PAD, INFO_NOTE_PAD)
    info_label.size = Vector2(inner_w, 10.0)
    info_label.text = text
    var content_h: float = maxf(info_label.get_content_height(), 20.0)
    info_label.size = Vector2(inner_w, content_h)
    var panel_h := content_h + INFO_NOTE_PAD * 2.0

    var pos_x := anchor_rect.position.x + anchor_rect.size.x + 24.0
    var pos_y := anchor_rect.get_center().y - panel_h / 2.0
    pos_x = clampf(pos_x, 0.0, DESIGN_CANVAS_SIZE.x - INFO_NOTE_W)
    pos_y = clampf(pos_y, 92.0, DESIGN_CANVAS_SIZE.y - panel_h)
    info_panel.position = Vector2(pos_x, pos_y)
    info_panel.size = Vector2(INFO_NOTE_W, panel_h)
    info_panel.show()


func hide_info_note() -> void:
    info_panel.hide()


# ---------------------------------------------------------------- Pulse frame

func show_pulse(rect: Rect2, padding: float = 6.0) -> void:
    var grown := rect.grow(padding)
    pulse_frame.position = grown.position
    pulse_frame.size = grown.size
    pulse_frame.pivot_offset = pulse_frame.size / 2.0
    pulse_frame.show()
    _restart_pulse_tween()


func hide_pulse() -> void:
    pulse_frame.hide()
    if _pulse_tween and _pulse_tween.is_valid():
        _pulse_tween.kill()


func _restart_pulse_tween() -> void:
    if _pulse_tween and _pulse_tween.is_valid():
        _pulse_tween.kill()
    pulse_frame.modulate = Color(1, 1, 1, 1)
    pulse_frame.scale = Vector2.ONE
    _pulse_tween = create_tween().set_loops()
    _pulse_tween.tween_property(pulse_frame, "modulate:a", 0.35, 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _pulse_tween.parallel().tween_property(pulse_frame, "scale", Vector2(1.04, 1.04), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _pulse_tween.tween_property(pulse_frame, "modulate:a", 1.0, 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _pulse_tween.parallel().tween_property(pulse_frame, "scale", Vector2.ONE, 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- Glow (informational "look
# here" highlight - used instead of set_spotlight's hard-edged mask cutout for targets that
# aren't buttons, e.g. the Power number or an enemy's intent icon. A cutout reads fine around
# a big rectangular button; around a single digit or small icon it just looks like a stray
# rough rectangle. Soft additive radial gradient instead - same visual language as the game's
# own power-orb/dice-aura glows (dice.gd::_get_power_orb_texture).

func _get_glow_texture() -> GradientTexture2D:
    if _glow_texture:
        return _glow_texture
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    var tex := GradientTexture2D.new()
    tex.gradient = gradient
    tex.width = 64
    tex.height = 64
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    _glow_texture = tex
    return _glow_texture


# NOTE: a "strength" multiplier was added here to make the Power number stand out and then
# removed - Julien rejected the look outright ("the gold glow looks bad"). Making a dim target
# readable is done by raising the TARGET's own opacity instead (see the director's
# _boost_power_visibility); this halo stays a quiet, fixed-strength "look here" marker.
func show_glow(rect: Rect2, color: Color = GLOW_COLOR_GOLD) -> void:
    if rect.size == Vector2.ZERO:
        return
    var diameter := minf(maxf(rect.size.x, rect.size.y) * GLOW_SIZE_FACTOR + GLOW_SIZE_PAD, GLOW_DIAMETER_CAP)
    glow.size = Vector2(diameter, diameter)
    glow.pivot_offset = glow.size / 2.0
    glow.position = rect.get_center() - glow.size / 2.0
    glow.modulate = Color(color.r, color.g, color.b, 0.0)
    glow.scale = Vector2(0.92, 0.92)
    glow.show()
    _restart_glow_tween()


func hide_glow() -> void:
    glow.hide()
    if _glow_tween and _glow_tween.is_valid():
        _glow_tween.kill()


func _restart_glow_tween() -> void:
    if _glow_tween and _glow_tween.is_valid():
        _glow_tween.kill()
    _glow_tween = create_tween().set_loops()
    _glow_tween.tween_property(glow, "modulate:a", GLOW_ALPHA_PEAK, 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _glow_tween.parallel().tween_property(glow, "scale", Vector2.ONE, 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _glow_tween.tween_property(glow, "modulate:a", GLOW_ALPHA_LOW, 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _glow_tween.parallel().tween_property(glow, "scale", Vector2(0.92, 0.92), 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- Text panel

func set_text(bbcode: String, zone: String = "center", show_continue: bool = false) -> void:
    _last_text = bbcode
    _last_zone = zone
    _last_continue = show_continue

    var z: Dictionary = TEXT_ZONES.get(zone, TEXT_ZONES["center"])
    var panel_w: float = _fit_panel_width(z, bbcode, show_continue)
    var inner_w: float = panel_w - PANEL_PAD_X * 2.0

    # Fully manual layout: anchors zeroed on all three nodes so NOTHING (theme defaults,
    # parent resizes, stale scene state) can reinterpret these rects - with zero anchors,
    # position/size ARE the rect, unconditionally.
    for c: Control in [text_panel, label, continue_button]:
        c.anchor_left = 0.0
        c.anchor_top = 0.0
        c.anchor_right = 0.0
        c.anchor_bottom = 0.0

    # Width first, then text, then read the shaped height - a non-threaded RichTextLabel
    # (threaded stays default-off here) shapes synchronously, so get_content_height() is
    # valid immediately once the wrap width is final.
    label.position = Vector2(PANEL_PAD_X, PANEL_PAD_Y)
    label.size = Vector2(inner_w, 10.0)
    label.text = bbcode
    var content_h: float = maxf(label.get_content_height(), 24.0)
    label.size = Vector2(inner_w, content_h)

    var panel_h: float = PANEL_PAD_Y * 2.0 + content_h
    if show_continue:
        panel_h += CONTINUE_GAP + CONTINUE_SIZE.y
        continue_button.position = Vector2(
            panel_w - PANEL_PAD_X - CONTINUE_SIZE.x,
            panel_h - PANEL_PAD_Y - CONTINUE_SIZE.y)
        continue_button.size = CONTINUE_SIZE
    continue_button.visible = show_continue

    var band_y0: float = z["y0"]
    var band_y1: float = z["y1"]
    var panel_y: float
    match String(z["attach"]):
        "top":
            panel_y = band_y0
        "bottom":
            panel_y = band_y1 - panel_h
        _:
            panel_y = band_y0 + (band_y1 - band_y0 - panel_h) / 2.0
    panel_y = maxf(panel_y, band_y0)

    # Speaker boxes keep their LEFT edge pinned: the bubble tail is placed at a fixed design-x
    # (the character's head) and clamped inside the box, so letting a fitted box drift
    # horizontally would drag the tail off the speaker. Everything else centres in its zone.
    var panel_x: float = z["x"]
    if not z.get("speaker", false):
        panel_x += (float(z["w"]) - panel_w) / 2.0
    text_panel.position = Vector2(panel_x, panel_y)
    text_panel.size = Vector2(panel_w, panel_h)
    text_panel.show()

    if z.get("speaker", false):
        _position_bubble_tail(Vector2(panel_x, panel_y), panel_w, panel_h)
        bubble_tail_border.show()
        bubble_tail_fill.show()
    else:
        bubble_tail_border.hide()
        bubble_tail_fill.hide()

    if OS.is_debug_build():
        call_deferred("_debug_report_panel_rect", zone)


# Picks the width whose resulting box comes closest to FIT_TARGET_ASPECT, among the widths
# whose box still fits inside the zone's vertical band. Cheap despite the loop: a RichTextLabel
# (non-threaded) reshapes synchronously, so each candidate is one measure, and this only runs
# on a step change. Falls back to the zone's full width when nothing fits the band.
func _fit_panel_width(z: Dictionary, bbcode: String, show_continue: bool) -> float:
    var max_w: float = z["w"]
    if not z.get("fit", false):
        return max_w
    var band_h: float = float(z["y1"]) - float(z["y0"])
    var best_w := max_w
    var best_score := INF
    var w := FIT_MIN_W
    while w <= max_w:
        var h := _measure_panel_height(bbcode, w, show_continue)
        if h <= band_h:
            var score := absf(w / h - FIT_TARGET_ASPECT)
            if score < best_score:
                best_score = score
                best_w = w
        w += FIT_STEP
    return best_w


func _measure_panel_height(bbcode: String, panel_w: float, show_continue: bool) -> float:
    label.size = Vector2(panel_w - PANEL_PAD_X * 2.0, 10.0)
    label.text = bbcode
    var panel_h: float = PANEL_PAD_Y * 2.0 + maxf(label.get_content_height(), 24.0)
    if show_continue:
        panel_h += CONTINUE_GAP + CONTINUE_SIZE.y
    return panel_h


# Small notch off the panel's bottom edge, reading as a speech-bubble tail pointing down at
# the character it's "coming from". Its horizontal position tracks SPEAKER_HEAD_X (the player
# character's head, clamped to stay within the box), so it points at the character regardless
# of the box's own height. Two stacked triangles (border-colored outer, bg-colored inner inset
# by SPEAKER_TAIL_BORDER) fake the panel's border without a real Polygon2D outline (it has
# none natively). Tip nudged left of the base center since the character sits down-and-left.
func _position_bubble_tail(panel_pos: Vector2, panel_w: float, panel_h: float) -> void:
    var cx := clampf(SPEAKER_HEAD_X, panel_pos.x + 30.0, panel_pos.x + panel_w - 30.0)
    var base_y := panel_pos.y + panel_h - 1.0
    var tip := Vector2(cx - 6.0, base_y + SPEAKER_TAIL_HEIGHT)
    bubble_tail_border.polygon = PackedVector2Array([
        Vector2(cx - SPEAKER_TAIL_HALF_W, base_y),
        Vector2(cx + SPEAKER_TAIL_HALF_W, base_y),
        tip,
    ])
    var inset := SPEAKER_TAIL_BORDER
    bubble_tail_fill.polygon = PackedVector2Array([
        Vector2(cx - SPEAKER_TAIL_HALF_W + inset, base_y - inset),
        Vector2(cx + SPEAKER_TAIL_HALF_W - inset, base_y - inset),
        Vector2(tip.x, tip.y - inset),
    ])


# One-line ground truth in the editor Output per step - if a panel ever renders somewhere
# other than what this prints, the discrepancy is BELOW this code (scene/theme/stretch),
# not in the layout math. Cheap enough to keep in debug builds.
func _debug_report_panel_rect(zone: String) -> void:
    print("[tutorial-overlay] zone=%s rect=%s visible=%s" % [zone, text_panel.get_rect(), text_panel.visible])


func hide_text() -> void:
    text_panel.hide()
    bubble_tail_border.hide()
    bubble_tail_fill.hide()


# ---------------------------------------------------------------- Welcome card

func show_welcome(title: String, body_bbcode: String) -> void:
    _welcome_title_text = title
    _welcome_body_text = body_bbcode
    _welcome_active = true
    hide_text()
    _layout_welcome()
    welcome_root.show()
    if is_inside_tree():
        _play_welcome_entrance()
    else:
        # Out of tree: no tweens allowed (see _ready). Land on the finished frame so the card
        # is never caught half-built if something renders before _ready gets its turn.
        welcome_root.modulate = Color(1, 1, 1, 1)
        welcome_root.scale = Vector2.ONE
        for c: CanvasItem in [welcome_title, welcome_divider, welcome_body, welcome_button]:
            c.modulate = Color(1, 1, 1, 1)
        welcome_divider.scale = Vector2.ONE


func hide_welcome() -> void:
    if not _welcome_active and not welcome_root.visible:
        return
    _welcome_active = false
    if _welcome_tween and _welcome_tween.is_valid():
        _welcome_tween.kill()
    if _welcome_glow_tween and _welcome_glow_tween.is_valid():
        _welcome_glow_tween.kill()
    _welcome_mote_timer.stop()
    for mote in _welcome_motes:
        if is_instance_valid(mote):
            mote.queue_free()
    _welcome_motes.clear()
    welcome_root.hide()


# Width-first, then shape the body, then derive the panel height from it - identical
# discipline to set_text, so the card fits whatever copy it's handed.
func _layout_welcome() -> void:
    var inner_w := WELCOME_W - WELCOME_PAD_X * 2.0

    for c: Control in [welcome_panel, welcome_title, welcome_divider, welcome_body, welcome_button]:
        c.anchor_left = 0.0
        c.anchor_top = 0.0
        c.anchor_right = 0.0
        c.anchor_bottom = 0.0

    welcome_title.text = _welcome_title_text
    welcome_title.position = Vector2(WELCOME_PAD_X, WELCOME_PAD_TOP)
    welcome_title.size = Vector2(inner_w, WELCOME_TITLE_H)

    var divider_y := WELCOME_PAD_TOP + WELCOME_TITLE_H + WELCOME_DIVIDER_TOP_GAP
    welcome_divider.position = Vector2(WELCOME_PAD_X, divider_y)
    welcome_divider.size = Vector2(inner_w, WELCOME_DIVIDER_H)
    welcome_divider.pivot_offset = welcome_divider.size / 2.0
    _layout_welcome_divider(inner_w)

    var body_y := divider_y + WELCOME_DIVIDER_H + WELCOME_BODY_TOP_GAP
    welcome_body.position = Vector2(WELCOME_PAD_X, body_y)
    welcome_body.size = Vector2(inner_w, 10.0)
    welcome_body.text = _welcome_body_text
    var body_h: float = maxf(welcome_body.get_content_height(), 24.0)
    welcome_body.size = Vector2(inner_w, body_h)

    var button_y := body_y + body_h + WELCOME_BUTTON_TOP_GAP
    welcome_button.size = WELCOME_BUTTON_SIZE
    welcome_button.position = Vector2((WELCOME_W - WELCOME_BUTTON_SIZE.x) / 2.0, button_y)

    var panel_h := button_y + WELCOME_BUTTON_SIZE.y + WELCOME_PAD_BOTTOM
    welcome_panel.size = Vector2(WELCOME_W, panel_h)
    welcome_panel.position = Vector2(
        (DESIGN_CANVAS_SIZE.x - WELCOME_W) / 2.0, WELCOME_CENTER_Y - panel_h / 2.0)

    # Warm halo bled well past the panel edges - the card should look lit from within rather
    # than pasted on. Additive, so it can only ever add light (never darken the art behind).
    var panel_center := welcome_panel.position + welcome_panel.size / 2.0
    var glow_size := welcome_panel.size * WELCOME_GLOW_SCALE
    welcome_glow.size = glow_size
    welcome_glow.position = panel_center - glow_size / 2.0
    welcome_glow.modulate = Color(
        WELCOME_GLOW_COLOR.r, WELCOME_GLOW_COLOR.g, WELCOME_GLOW_COLOR.b, WELCOME_GLOW_ALPHA_LOW)

    # Scaling the (full-screen) root about the panel's centre is what makes the entrance pop
    # read as the whole card arriving, halo included.
    welcome_root.pivot_offset = panel_center


# Two gold rules tapering away from a small diamond. The rules are gradient textures rather
# than flat bars specifically so they fade out instead of ending on a hard chopped edge.
func _layout_welcome_divider(inner_w: float) -> void:
    var cy := WELCOME_DIVIDER_H / 2.0
    var half := WELCOME_DIAMOND / 2.0
    var rule_w: float = maxf(inner_w / 2.0 - half - WELCOME_RULE_GAP, 10.0)

    welcome_rule_left.size = Vector2(rule_w, WELCOME_RULE_H)
    welcome_rule_left.position = Vector2(0.0, cy - WELCOME_RULE_H / 2.0)
    welcome_rule_right.size = Vector2(rule_w, WELCOME_RULE_H)
    welcome_rule_right.position = Vector2(inner_w - rule_w, cy - WELCOME_RULE_H / 2.0)

    welcome_diamond.size = Vector2(WELCOME_DIAMOND, WELCOME_DIAMOND)
    welcome_diamond.pivot_offset = welcome_diamond.size / 2.0
    welcome_diamond.rotation = PI / 4.0
    welcome_diamond.position = Vector2(inner_w / 2.0 - half, cy - half)


# Staged rather than one flat fade: card pops in, title lifts into place a beat later, the
# divider draws itself outward from the diamond, then body and button settle. The order is
# the point - it reads as a curtain going up instead of a dialog appearing.
func _play_welcome_entrance() -> void:
    if _welcome_tween and _welcome_tween.is_valid():
        _welcome_tween.kill()

    # Canonical resting y, NOT welcome_title.position.y - reading the live position would
    # compound the offset if this ever ran twice without a re-layout in between.
    var title_y := WELCOME_PAD_TOP
    welcome_root.modulate = Color(1, 1, 1, 0)
    welcome_root.scale = Vector2(0.9, 0.9)
    welcome_title.modulate = Color(1, 1, 1, 0)
    welcome_title.position.y = title_y + WELCOME_TITLE_RISE
    welcome_divider.scale = Vector2(0.0, 1.0)
    welcome_body.modulate = Color(1, 1, 1, 0)
    welcome_button.modulate = Color(1, 1, 1, 0)

    # Paced deliberately slowly (~1.9s end to end) - this beat is the game introducing itself,
    # so each element gets its own moment rather than the whole card arriving at once.
    _welcome_tween = create_tween().set_parallel(true)
    _welcome_tween.tween_property(welcome_root, "modulate:a", 1.0, 0.34) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _welcome_tween.tween_property(welcome_root, "scale", Vector2.ONE, 0.7) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _welcome_tween.tween_property(welcome_title, "modulate:a", 1.0, 0.5).set_delay(0.34)
    _welcome_tween.tween_property(welcome_title, "position:y", title_y, 0.72).set_delay(0.34) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _welcome_tween.tween_property(welcome_divider, "scale", Vector2.ONE, 0.66).set_delay(0.66) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _welcome_tween.tween_property(welcome_body, "modulate:a", 1.0, 0.46).set_delay(1.0)
    _welcome_tween.tween_property(welcome_button, "modulate:a", 1.0, 0.42).set_delay(1.45)

    _restart_welcome_glow_tween()
    _welcome_mote_timer.start()


func _restart_welcome_glow_tween() -> void:
    if _welcome_glow_tween and _welcome_glow_tween.is_valid():
        _welcome_glow_tween.kill()
    _welcome_glow_tween = create_tween().set_loops()
    _welcome_glow_tween.tween_property(welcome_glow, "modulate:a", WELCOME_GLOW_ALPHA_PEAK, 1.5) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _welcome_glow_tween.tween_property(welcome_glow, "modulate:a", WELCOME_GLOW_ALPHA_LOW, 1.5) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Slow warm embers drifting up past the card - same additive-mote language as the dice
# infusion screen and the shop's deal die. Spawned BEHIND the panel (index 1, just above the
# halo) so they can never sit on top of the text; they're read in the margins around it.
func _spawn_welcome_mote() -> void:
    if not _welcome_active:
        return
    var mote := TextureRect.new()
    mote.texture = _get_glow_texture()
    mote.stretch_mode = TextureRect.STRETCH_SCALE
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    mote.material = mat

    var s := randf_range(10.0, 20.0)
    mote.size = Vector2(s, s)
    # Spawn in the open margin BESIDE the card, never under it: a first pass spread them
    # across the panel's own width and every one of them was swallowed by the panel and halo.
    var panel_rect := Rect2(welcome_panel.position, welcome_panel.size)
    var margin := 150.0
    var left_side := randf() < 0.5
    var start_x: float = randf_range(panel_rect.position.x - margin, panel_rect.position.x - 14.0) \
        if left_side else randf_range(panel_rect.end.x + 14.0, panel_rect.end.x + margin)
    var start := Vector2(start_x, panel_rect.end.y + randf_range(-40.0, 40.0))
    mote.position = start
    mote.modulate = Color(WELCOME_MOTE_COLOR.r, WELCOME_MOTE_COLOR.g, WELCOME_MOTE_COLOR.b, 0.0)

    welcome_root.add_child(mote)
    welcome_root.move_child(mote, 1)
    _welcome_motes.append(mote)

    var rise := randf_range(140.0, 260.0)
    var drift := randf_range(-26.0, 26.0)
    var life := randf_range(1.8, 3.0)
    var peak := randf_range(0.4, 0.7)

    var tw := mote.create_tween()
    tw.set_parallel(true)
    tw.tween_property(mote, "position", start + Vector2(drift, -rise), life) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.tween_property(mote, "modulate:a", peak, life * 0.3) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.chain().tween_property(mote, "modulate:a", 0.0, life * 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(func():
        _welcome_motes.erase(mote)
        mote.queue_free())


# ---------------------------------------------------------------- Lifecycle

func start() -> void:
    skip_button.show()


# Full reset between steps / on skip - callers still call the specific show_* methods
# right after for whatever the next step actually needs.
func clear_all() -> void:
    hide_pointer()
    hide_info_pointer()
    hide_info_note()
    hide_pulse()
    hide_glow()
    hide_text()
    hide_welcome()
    set_dim(Dim.NONE)


func shutdown() -> void:
    clear_all()
    skip_button.hide()
