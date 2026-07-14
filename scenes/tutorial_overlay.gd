class_name TutorialOverlay
extends CanvasLayer

## Reusable affordance kit for the combat tutorial (tutorial_redesign_2026-07.md §5) -
## TutorialDirector drives it entirely through this small set of methods, it owns no
## tutorial-specific knowledge of its own. Lives on a high layer (see .tscn) so it renders
## above every other CanvasLayer in battle.tscn, including the victory screen.

signal continue_pressed
signal skip_pressed

enum Dim { NONE, SOFT, FULL }
enum PointerDir { DOWN, UP }

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
    "center": {"x": 320.0, "w": 640.0, "y0": 170.0, "y1": 500.0, "attach": "center"},
    "top": {"x": 280.0, "w": 720.0, "y0": 100.0, "y1": 280.0, "attach": "top"},
    # above_hand bottom raised again (524 -> 450): the tutorial-lifted card rises ~60px, and
    # because the overlay is on a HIGHER CanvasLayer than the hand it always draws OVER the
    # card - so the box's bottom edge must sit ABOVE the lifted card's top, or the card pokes
    # awkwardly out from behind it (Julien: "still that weird card highlight"). Trade-off: a
    # long card-step box now grows up over the die, which is acceptable since the card, not the
    # die, is the focus of those steps.
    "above_hand": {"x": 320.0, "w": 640.0, "y0": 290.0, "y1": 450.0, "attach": "bottom"},
    # near_dice is BOTTOM-attached (was center): the speech-bubble tail hangs off the box's
    # bottom edge, so a bottom-anchored box keeps that edge - and thus the tail - at a fixed
    # height no matter how tall the text is. y1 raised (335 -> 310) so the box clears the
    # hero's idle-animation bob (Julien: "hero moves a bit, box not high enough for him").
    "near_dice": {"x": 90.0, "w": 360.0, "y0": 120.0, "y1": 310.0, "attach": "bottom", "speaker": true},
    "near_enemy": {"x": 690.0, "w": 420.0, "y0": 300.0, "y1": 566.0, "attach": "bottom"},
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

const ARROW_TEXTURES := {
    PointerDir.DOWN: preload("res://tutorial_arrow_down.png"),
    PointerDir.UP: preload("res://tutorial_arrow.png"),
}

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

var _pulse_tween: Tween
var _bob_tween: Tween
var _glow_tween: Tween
var _glow_texture: GradientTexture2D

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
    if _is_setup and _last_text != "" and text_panel.visible:
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

func set_dim(mode: Dim) -> void:
    var a: float = DIM_ALPHA.get(mode, 0.0)
    for m in _masks:
        var c := m.color
        c.a = a
        m.color = c
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
    # Always use the DOWN texture and flip it vertically for UP - the standalone "up" art
    # (tutorial_arrow.png) doesn't actually point straight up, so flipping the known-good down
    # arrow guarantees the correct orientation (the relic arrow was pointing sideways).
    pointer_arrow.texture = ARROW_TEXTURES[PointerDir.DOWN]
    pointer_arrow.flip_v = direction == PointerDir.UP
    pointer_arrow.pivot_offset = pointer_arrow.size / 2.0
    match direction:
        PointerDir.DOWN:  # tip points down - sits ABOVE the target
            pointer_arrow.position = target_point - Vector2(pointer_arrow.size.x / 2.0, pointer_arrow.size.y + POINTER_GAP)
        PointerDir.UP:  # tip points up - sits BELOW the target
            pointer_arrow.position = target_point - Vector2(pointer_arrow.size.x / 2.0, -POINTER_GAP)
    pointer_arrow.show()
    _restart_bob_tween()


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


func _restart_bob_tween() -> void:
    if _bob_tween and _bob_tween.is_valid():
        _bob_tween.kill()
    var base_y := pointer_arrow.position.y
    _bob_tween = create_tween().set_loops()
    _bob_tween.tween_property(pointer_arrow, "position:y", base_y - POINTER_BOB_DISTANCE, POINTER_BOB_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob_tween.tween_property(pointer_arrow, "position:y", base_y, POINTER_BOB_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Second, informational arrow (see info_arrow). Always points DOWN, sitting above target_point.
# Deliberately STATIC (no bob) - Julien wanted the power arrow to sit still, unlike the bobbing
# action pointer, so it reads as a label rather than a "do something here" prompt.
func show_info_pointer(target_point: Vector2) -> void:
    info_arrow.position = target_point - Vector2(info_arrow.size.x / 2.0, info_arrow.size.y + POINTER_GAP)
    info_arrow.show()


func hide_info_pointer() -> void:
    info_arrow.hide()


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
    var panel_w: float = z["w"]
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

    text_panel.position = Vector2(z["x"], panel_y)
    text_panel.size = Vector2(panel_w, panel_h)
    text_panel.show()

    if z.get("speaker", false):
        _position_bubble_tail(text_panel.position, panel_w, panel_h)
        bubble_tail_border.show()
        bubble_tail_fill.show()
    else:
        bubble_tail_border.hide()
        bubble_tail_fill.hide()

    if OS.is_debug_build():
        call_deferred("_debug_report_panel_rect", zone)


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
    set_dim(Dim.NONE)


func shutdown() -> void:
    clear_all()
    skip_button.hide()
