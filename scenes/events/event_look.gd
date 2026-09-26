# Runtime look for the event screens (H-189, plan: map_event_look_plan_2026-09.md).
#   E1  The event's own picture becomes the room: the picture, shrunk and stretched back (a free
#       blur) and darkened, fills the screen; the WHOLE picture sits on the left with soft edges
#       and no frame (the old 470 px square crop hid ~1/3 of the 17 landscape pictures); the
#       title and text sit on the right on a dark shade.
#   E3  A little life in the picture: slow glowing specks per event (event_ambience.gd).
#   E4  Gold and HP amounts in the choice buttons get the top bar's coin and heart.
#
# All 22 pooled events share one 13-node skeleton (checked by script on 2026-09-25), so this
# restyles them at runtime when run.gd opens one, and the .tscn files stay untouched. The editor
# still shows the old navy panel, which is fine for writing text. An event that does not match
# the skeleton is left exactly as it is (with a warning).
#
# Deliberately NO class_name: consumers preload() it, so nothing needs the global class cache
# regenerated (same reason as event_modal_text.gd).
extends RefCounted

const EventAmbience := preload("res://scenes/events/event_ambience.gd")
const FEATHER_SHADER := preload("res://scenes/events/event_art_feather.gdshader")
const COIN_ICON := "res://assets/images/ui/inline_coin.png"
const HEART_ICON := "res://assets/images/ui/inline_heart.png"

# Debug overlay "LOOK" button flips this: false = the old navy panel, from the next event on.
static var enabled := true

const PATHS := {
    "bg": "TextureRect",
    "outer": "TextureRect/MarginContainer",
    "panel": "TextureRect/MarginContainer/Panel",
    "inner": "TextureRect/MarginContainer/Panel/MarginContainer",
    "banner": "TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/Panel",
    "title": "TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/Panel/Label",
    "hbox": "TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer",
    "art_frame": "TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/ArtFrame",
    "art": "TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/ArtFrame/TextureRect",
    "column": "TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer",
}

# --- E1 geometry (event root sits at screen y 35, so root-local y = screen y - 35) ---------
# Picture slot 700 x 470 at screen x 26; text column x 742..1244 (502 wide, was 500); column
# top at screen y 141 (margin 106 + 35), bottom at screen y 694 (720 + 35 - 61). Found on the
# mockup, then measured in the harness (debug_look_lab_capture.gd, LOOKLAB_MODE=verify).
const ART_SLOT := Vector2(700, 470)
const OUTER_MARGINS := {"left": 26, "top": 106, "right": 36, "bottom": 61}
const ART_TEXT_GAP := 16
const FEATHER_PX := Vector4(34, 34, 90, 34)  # left, top, right (towards the text), bottom
const GLOW_GROW := 80.0
# 0.55 left a bright haze above bright pictures (the spring's steam), 0.4 keeps the bleed.
const GLOW_STRENGTH := 0.4
const BACKDROP_DARKEN := 0.30
const BLUR_SMALL_WIDTH := 40
const TITLE_FONT_SIZE := 34
const BODY_FONT_SIZE := 24
const BODY_COLOR := Color("f4ecd8")
const BODY_SHADOW := Color(0, 0, 0, 0.63)

# --- E4 --------------------------------------------------------------------------------------
# Choice buttons are Belwe 18: icons at font size + 2, the Power glyph's convention. "Max HP"
# keeps its words on purpose (a heart would read as a heal); it needs its own mark first.
const ICON_PX := 20
static var _re_gold: RegEx
static var _re_hp: RegEx

# --- E3 --------------------------------------------------------------------------------------
# Scene file name -> emitters. area = where specks start, in 0..1 of the picture. A first pass
# from looking at each picture; tune freely (plan, section 3). Missing = no specks.
const AMBIENCE := {
    "event_healing_spring": [
        {"preset": "mist", "area": Rect2(0.02, 0.35, 0.96, 0.6)},
        {"preset": "glints", "area": Rect2(0.12, 0.6, 0.78, 0.38)},
    ],
    "event_fountain_heal": [
        {"preset": "glints", "area": Rect2(0.2, 0.2, 0.6, 0.55), "count": 22},
        {"preset": "mist", "area": Rect2(0.1, 0.45, 0.8, 0.45), "count": 6},
    ],
    "event_crimson_eclipse": [
        {"preset": "embers", "area": Rect2(0.04, 0.72, 0.92, 0.28)},
        {"preset": "ash", "area": Rect2(0.0, 0.0, 1.0, 0.65)},
    ],
    "event_patient_monk": [
        {"preset": "motes", "area": Rect2(0.28, 0.05, 0.62, 0.9)},
    ],
    "event_golden_die_shrine": [
        {"preset": "motes", "area": Rect2(0.2, 0.1, 0.6, 0.8)},
    ],
    "event_twin_shrines": [
        {"preset": "motes", "area": Rect2(0.1, 0.1, 0.8, 0.8), "count": 30},
    ],
    "event_deonassius": [
        {"preset": "motes", "area": Rect2(0.2, 0.3, 0.7, 0.65), "count": 26},
    ],
    "event_wayside_shrine": [
        {"preset": "embers", "area": Rect2(0.22, 0.35, 0.3, 0.57), "count": 18, "color": Color(1.0, 0.35, 0.27)},
        {"preset": "glints", "area": Rect2(0.54, 0.45, 0.28, 0.53), "count": 20, "color": Color(0.47, 0.93, 1.0)},
    ],
    "event_dice_arcanist": [
        {"preset": "orbit", "center": Vector2(0.6, 0.55)},
    ],
    "event_fickle_broker": [
        {"preset": "motes", "area": Rect2(0.2, 0.1, 0.65, 0.75), "count": 26, "color": Color(0.8, 0.55, 1.0)},
    ],
    "event_wandering_merchant": [
        {"preset": "motes", "area": Rect2(0.3, 0.2, 0.5, 0.7), "count": 24, "color": Color(0.8, 0.55, 1.0)},
    ],
    "event_whetstone_shrine": [
        {"preset": "embers", "area": Rect2(0.3, 0.35, 0.45, 0.4), "count": 22, "color": Color(1.0, 0.75, 0.3)},
    ],
    "event_dice_machine": [
        {"preset": "mist", "area": Rect2(0.1, 0.05, 0.8, 0.45), "count": 10, "color": Color(0.82, 0.82, 0.82)},
    ],
    "event_hollow_idol": [
        {"preset": "embers", "area": Rect2(0.2, 0.3, 0.6, 0.7), "count": 20, "color": Color(0.75, 0.45, 1.0)},
    ],
    "event_more_money_for_hp": [
        {"preset": "embers", "area": Rect2(0.2, 0.2, 0.6, 0.6), "count": 24, "color": Color(0.78, 0.42, 1.0)},
    ],
    "event_relic_or_heal": [
        {"preset": "orbit", "center": Vector2(0.5, 0.58), "count": 28, "color": Color(1.0, 0.6, 0.25), "color2": Color(1.0, 0.85, 0.45)},
    ],
    "event_buy_relic": [
        {"preset": "glints", "area": Rect2(0.2, 0.2, 0.7, 0.7), "count": 16, "color": Color(1.0, 0.88, 0.5)},
    ],
    "event_gold_dice": [
        {"preset": "glints", "area": Rect2(0.45, 0.45, 0.35, 0.4), "count": 14, "color": Color(1.0, 0.88, 0.5)},
    ],
    "event_relic_or_cards": [
        {"preset": "motes", "area": Rect2(0.2, 0.3, 0.6, 0.6), "count": 20},
    ],
    "event_remove_card_hp": [
        {"preset": "motes", "area": Rect2(0.1, 0.1, 0.8, 0.8), "count": 18},
    ],
    "event_russian_dice": [
        {"preset": "motes", "area": Rect2(0.1, 0.1, 0.8, 0.7), "count": 16},
    ],
}

static var _shade_textures: Array[Texture2D] = []


static func apply(root: Control, event_name: String) -> void:
    if not enabled or root == null:
        return
    var n := _skeleton(root)
    if n.is_empty():
        push_warning("EventLook: %s does not match the event layout, left as is" % event_name)
        return
    _apply_room(n)
    _apply_ambience(n, event_name)
    _apply_choice_icons(n)


static func _skeleton(root: Control) -> Dictionary:
    var n := {}
    for key: String in PATHS:
        var node := root.get_node_or_null(PATHS[key])
        if node == null:
            return {}
        n[key] = node
    for child: Node in (n["column"] as Node).get_children():
        if child is RichTextLabel and not n.has("body"):
            n["body"] = child
        elif child is VBoxContainer and not n.has("buttons"):
            n["buttons"] = child
    if not n.has("body") or not n.has("buttons") or (n["art"] as TextureRect).texture == null:
        return {}
    return n


# ---------------------------------------------------------------------------- E1

static func _apply_room(n: Dictionary) -> void:
    var bg: TextureRect = n["bg"]
    var art: TextureRect = n["art"]
    var picture: Texture2D = art.texture
    var blurred := _blurred(picture)

    # Backdrop: the picture itself, blurred and darkened. self_modulate, never modulate: modulate
    # would darken every child of this node, i.e. the whole event.
    bg.texture = blurred
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    bg.self_modulate = Color(BACKDROP_DARKEN, BACKDROP_DARKEN, BACKDROP_DARKEN)

    # Shades under all the content: corners, the text column, the relic row.
    var textures := _get_shade_textures()
    for i in textures.size():
        var shade := TextureRect.new()
        shade.name = "LookShade%d" % i
        shade.texture = textures[i]
        shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        shade.stretch_mode = TextureRect.STRETCH_SCALE
        shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(shade)
        bg.move_child(shade, i)
        shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # No panel, no banner: the title moves above the text.
    (n["panel"] as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    var column: VBoxContainer = n["column"]
    var title: Label = n["title"]
    title.reparent(column, false)
    column.move_child(title, 0)
    if title.label_settings:
        var settings := title.label_settings.duplicate() as LabelSettings  # shared resource
        settings.font_size = TITLE_FONT_SIZE
        title.label_settings = settings
    title.custom_minimum_size = Vector2.ZERO
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    (n["banner"] as Control).visible = false

    # Layout: the outer margins place the picture slot and the text column.
    var outer: MarginContainer = n["outer"]
    for side: String in OUTER_MARGINS:
        outer.add_theme_constant_override("margin_" + side, OUTER_MARGINS[side])
    var inner: MarginContainer = n["inner"]
    for side: String in ["left", "top", "right", "bottom"]:
        inner.add_theme_constant_override("margin_" + side, 0)
    (n["hbox"] as HBoxContainer).add_theme_constant_override("separation", ART_TEXT_GAP)

    # The whole picture, no frame, soft edges, smooth filtering (the project default is
    # NEAREST and the event art has no mipmaps, so it aliased at the old 0.55x scale).
    var frame: PanelContainer = n["art_frame"]
    frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    frame.custom_minimum_size = Vector2(ART_SLOT.x, 0)
    frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var fitted := _fit(picture.get_size(), ART_SLOT)
    art.custom_minimum_size = fitted
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_SCALE
    art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    art.material = _feather_material(fitted, FEATHER_PX)

    # Glow: the picture's own colours bled past its edge, drawn behind it, so the soft edge
    # lands on matching colour instead of on a different (cover-scaled) copy of the picture.
    var glow := TextureRect.new()
    glow.name = "LookGlow"
    glow.texture = blurred
    glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.show_behind_parent = true
    glow.self_modulate = Color(GLOW_STRENGTH, GLOW_STRENGTH, GLOW_STRENGTH)
    glow.material = _feather_material(fitted + Vector2(GLOW_GROW, GLOW_GROW) * 2.0,
            Vector4(GLOW_GROW, GLOW_GROW, GLOW_GROW, GLOW_GROW))
    art.add_child(glow)
    glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    glow.offset_left = -GLOW_GROW
    glow.offset_top = -GLOW_GROW
    glow.offset_right = GLOW_GROW
    glow.offset_bottom = GLOW_GROW

    # Body text: cream on the dark shade, one step smaller so the 502 px column wraps like the
    # old 500 px one did at 26.
    var body: RichTextLabel = n["body"]
    body.custom_minimum_size = Vector2.ZERO
    # Every size, not just normal: [b]/[i] words fall to the theme's 26 otherwise.
    for size_name: String in ["normal_font_size", "bold_font_size", "italics_font_size",
            "bold_italics_font_size"]:
        body.add_theme_font_size_override(size_name, BODY_FONT_SIZE)
    body.add_theme_color_override("default_color", BODY_COLOR)
    body.add_theme_color_override("font_shadow_color", BODY_SHADOW)
    body.add_theme_constant_override("shadow_offset_x", 2)
    body.add_theme_constant_override("shadow_offset_y", 2)


# A picture shrunk to 40 px wide then stretched back up is a soft blur for free: no shader, no
# extra asset. Event art imports are Lossy WebP, so get_image() decodes; decompress() covers a
# VRAM-compressed import if one ever appears.
static func _blurred(picture: Texture2D) -> Texture2D:
    var img := picture.get_image()
    if img == null:
        return picture
    if img.is_compressed():
        img.decompress()
    img.convert(Image.FORMAT_RGBA8)
    var w := BLUR_SMALL_WIDTH
    var h := maxi(1, roundi(w * float(img.get_height()) / float(img.get_width())))
    img.resize(w, h, Image.INTERPOLATE_LANCZOS)
    img.resize(w * 8, h * 8, Image.INTERPOLATE_CUBIC)
    return ImageTexture.create_from_image(img)


static func _fit(picture_size: Vector2, box: Vector2) -> Vector2:
    var s := minf(box.x / picture_size.x, box.y / picture_size.y)
    return (picture_size * s).round()


static func _feather_material(rect: Vector2, feather: Vector4) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = FEATHER_SHADER
    # Both seeded at creation (H-004/H-036: never rely on an unassigned uniform).
    mat.set_shader_parameter("rect_px", rect)
    mat.set_shader_parameter("feather_px", feather)
    return mat


# [corner vignette, text-column shade, relic-row shade], black with alpha, stretched over the
# event root (1280 x 720, starting at screen y 35).
static func _get_shade_textures() -> Array[Texture2D]:
    if _shade_textures.is_empty():
        _shade_textures.append(_gradient_texture(
                [0.0, 0.55, 1.0], [0.0, 0.0, 0.35], Vector2(0.5, 0.51), Vector2(1.0, 0.51), true))
        # 600 px -> 0, 900 px -> 0.70, right edge -> 0.76
        _shade_textures.append(_gradient_texture(
                [0.0, 0.469, 0.703, 1.0], [0.0, 0.0, 0.70, 0.76], Vector2(0, 0), Vector2(1, 0), false))
        # 0.62 down to screen y 118, fading out by screen y 232 (root-local 83 and 197 of 720)
        _shade_textures.append(_gradient_texture(
                [0.0, 0.115, 0.274, 1.0], [0.62, 0.62, 0.0, 0.0], Vector2(0, 0), Vector2(0, 1), false))
    return _shade_textures


static func _gradient_texture(offsets: Array, alphas: Array, from: Vector2, to: Vector2,
        radial: bool) -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array(offsets)
    var colors := PackedColorArray()
    for a: float in alphas:
        colors.append(Color(0, 0, 0, a))
    gradient.colors = colors
    var tex := GradientTexture2D.new()
    tex.gradient = gradient
    tex.width = 256
    tex.height = 256
    tex.fill = GradientTexture2D.FILL_RADIAL if radial else GradientTexture2D.FILL_LINEAR
    tex.fill_from = from
    tex.fill_to = to
    return tex


# ---------------------------------------------------------------------------- E3

static func _apply_ambience(n: Dictionary, event_name: String) -> void:
    var emitters: Array = AMBIENCE.get(event_name, [])
    if emitters.is_empty():
        return
    var ambience := EventAmbience.new()
    ambience.name = "LookAmbience"
    ambience.emitters = emitters
    ambience.feather_px = FEATHER_PX
    (n["art"] as TextureRect).add_child(ambience)


# ---------------------------------------------------------------------------- E4

static func _apply_choice_icons(n: Dictionary) -> void:
    for button: Node in (n["buttons"] as Node).get_children():
        if not button is Button:
            continue
        for child: Node in button.get_children():
            if child is RichTextLabel:
                var label := child as RichTextLabel
                label.text = iconify_choice(label.text)


# "Pay 25 Gold." -> "Pay 25" + coin, "Heal 10 HP." -> "Heal 10" + heart. The number and the
# icon are welded with a no-break space so the icon can never wrap onto its own line. "8 Max
# HP" never matches (a word sits between the number and HP).
static func iconify_choice(text: String, px: int = ICON_PX) -> String:
    if _re_gold == null:
        _re_gold = RegEx.create_from_string("(\\d+) Gold\\.?")
        _re_hp = RegEx.create_from_string("(\\d+) HP\\.?")
    var weld := "$1" + KeywordColorizer.NBSP
    text = _re_gold.sub(text, weld + "[img=%d]%s[/img]" % [px, COIN_ICON], true)
    text = _re_hp.sub(text, weld + "[img=%d]%s[/img]" % [px, HEART_ICON], true)
    return text
