extends Control

# The act-transition power spike (Slay the Spire 2 "ancient relic" beat): shown by
# run.gd right after the act-1 boss reward screen exits, INSTEAD of the map. Rolls 2
# owned dice types that have an infusion designed (custom_resources/dice_infusions.gd),
# presents both as big ceremonial panels, and locks the pick into Global.dice_infusions.
# Picking is MANDATORY (pure upside, part of the run's pacing - Julien's call,
# 2026-07-14): there is no skip button. Confirming plays a flash/burst ceremony, then
# emits Events.dice_infusion_completed, which run.gd answers by entering act 2 and
# showing the new map.
#
# All fonts/styles are built in code (same reason as tutorial_overlay.gd: the project
# theme's decorative Cinzel is unreadable at body sizes, and code-built option panels
# keep the candidate count flexible for future infusions).

const FONT_TITLE := preload("res://fonts/MinionPro-Bold.otf")
const FONT_SUBTITLE := preload("res://fonts/MinionPro-Semibold.otf")
const FONT_CHUNKY := preload("res://fonts/LuckiestGuy-Regular.ttf")
const FONT_BODY := preload("res://fonts/NotoSans-Regular.ttf")
const INFUSE_SOUND := preload("res://chargedicesound.mp3")

const GOLD := Color(0.788235, 0.635294, 0.152941)  # the universal card-border gold
const TITLE_GOLD := Color(0.972439, 0.866667, 0.541176)  # act-banner gold
const CREAM := Color(0.93, 0.88, 0.8)
const PANEL_BG := Color(0.075, 0.055, 0.11)

# Height dropped 430 -> 382 on 2026-08-06 to buy the room the title needed once it moved
# clear of the relic band; the Options HBox is now y 254..636 and the INFUSE button starts
# at 644, so a taller panel would grow straight through it.
const PANEL_MIN_SIZE := Vector2(370, 382)
const DIE_SIZE := 170.0
const DIE_HOLDER_SIZE := Vector2(210.0, 190.0)
const GLOW_SIZE := 300.0
const MOTE_INTERVAL := 0.4

@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var options_box: HBoxContainer = $Options
@onready var infuse_button: Button = $InfuseButton

var _selected_type := ""
var _hovered_type := ""
var _confirmed := false
var _panels := {}  # dice type -> PanelContainer
var _glows := {}  # dice type -> TextureRect (the additive halo behind the die)
var _dies := {}  # dice type -> TextureRect (the die face itself)
var _pulse_tweens := {}  # dice type -> looping glow Tween (killed on confirm)

# Shared soft radial texture + additive material for glow/motes - same recipe as the
# power orbs (dice.gd::_get_power_orb_texture), duplicated here because those caches
# are dice.gd instance state.
static var _glow_texture: GradientTexture2D
static var _additive_material: CanvasItemMaterial


func _ready() -> void:
    _style_chrome()
    infuse_button.pressed.connect(_on_infuse_pressed)

    var candidates := DiceInfusions.roll_candidates()
    if candidates.is_empty():
        # Impossible today (Blue & Red are always owned and both have infusions), but
        # never soft-lock the act transition if a future change breaks that assumption.
        push_warning("Dice infusion: no eligible dice types - skipping straight to act 2")
        Events.dice_infusion_completed.emit.call_deferred()
        return

    for dice_type: String in candidates:
        var panel := _build_option_panel(dice_type)
        options_box.add_child(panel)

    _play_entrance()


func _style_chrome() -> void:
    var title_settings := LabelSettings.new()
    title_settings.font = FONT_TITLE
    title_settings.font_size = 58
    title_settings.font_color = TITLE_GOLD
    title_settings.outline_size = 6
    title_settings.outline_color = Color(0.196078, 0.0823529, 0, 1)
    title_settings.shadow_size = 8
    title_settings.shadow_color = Color(0, 0, 0, 0.7)
    title_settings.shadow_offset = Vector2(3, 3)
    title_label.label_settings = title_settings

    var subtitle_settings := LabelSettings.new()
    subtitle_settings.font = FONT_SUBTITLE
    subtitle_settings.font_size = 19
    subtitle_settings.font_color = CREAM
    subtitle_settings.shadow_size = 4
    subtitle_settings.shadow_color = Color(0, 0, 0, 0.6)
    subtitle_settings.shadow_offset = Vector2(2, 2)
    subtitle_label.label_settings = subtitle_settings

    infuse_button.add_theme_font_override("font", FONT_TITLE)
    infuse_button.add_theme_font_size_override("font_size", 26)
    infuse_button.add_theme_color_override("font_color", TITLE_GOLD)
    infuse_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
    infuse_button.add_theme_color_override("font_pressed_color", TITLE_GOLD)
    infuse_button.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.45))
    infuse_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.086, 0.157, 0.165), GOLD))
    infuse_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.12, 0.21, 0.22), GOLD.lightened(0.3)))
    infuse_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.06, 0.11, 0.12), GOLD))
    infuse_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.07, 0.09, 0.1), Color(0.35, 0.33, 0.28)))


func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.shadow_color = Color(0, 0, 0, 0.4)
    style.shadow_size = 4
    return style


func _make_panel_style(border_color: Color, emphasized: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_BG
    style.set_border_width_all(4 if emphasized else 3)
    style.border_color = border_color
    style.set_corner_radius_all(14)
    if emphasized:
        # The "glow" of a selected/hovered panel is its shadow in the border color.
        style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.4)
        style.shadow_size = 16
    else:
        style.shadow_color = Color(0, 0, 0, 0.45)
        style.shadow_size = 8
    return style


func _build_option_panel(dice_type: String) -> PanelContainer:
    var info: Dictionary = DiceInfusions.get_info(dice_type)
    var accent: Color = info["accent"]

    var panel := PanelContainer.new()
    panel.name = dice_type.capitalize() + "Option"
    panel.custom_minimum_size = PANEL_MIN_SIZE
    panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _make_panel_style(GOLD, false))
    panel.gui_input.connect(_on_panel_gui_input.bind(dice_type))
    panel.mouse_entered.connect(_on_panel_hover.bind(dice_type, true))
    panel.mouse_exited.connect(_on_panel_hover.bind(dice_type, false))

    var margin := MarginContainer.new()
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 22)
    panel.add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_theme_constant_override("separation", 4)
    # Center vertically so the min-size slack splits evenly instead of pooling at the
    # bottom (the two descriptions wrap to different line counts).
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    margin.add_child(vbox)

    # What the die is now: "BLUE DICE", in its BASE identity color (deliberately the
    # base ACCENT const, not DicePalette.accent() - nothing is infused yet).
    var base_label := Label.new()
    base_label.text = ("%s Dice" % KeywordColorizer.dice_display_name(dice_type)).to_upper()
    base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    base_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var base_settings := LabelSettings.new()
    base_settings.font = FONT_CHUNKY
    base_settings.font_size = 17
    base_settings.font_color = DicePalette.ACCENT.get(dice_type, Color.WHITE)
    base_settings.outline_size = 4
    base_settings.outline_color = Color(0, 0, 0, 0.8)
    base_label.label_settings = base_settings
    vbox.add_child(base_label)

    var becomes_label := Label.new()
    becomes_label.text = "awakens into"
    becomes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    becomes_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var becomes_settings := LabelSettings.new()
    becomes_settings.font = FONT_BODY
    becomes_settings.font_size = 13
    becomes_settings.font_color = Color(0.72, 0.68, 0.6)
    becomes_label.label_settings = becomes_settings
    vbox.add_child(becomes_label)

    # The die itself, face 6 (the Arcane trigger face - and the "best roll" face on
    # every d6 type), with an additive halo pulsing behind it in the infused accent.
    var die_holder := CenterContainer.new()
    die_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(die_holder)

    var visual := Control.new()
    visual.custom_minimum_size = DIE_HOLDER_SIZE
    visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
    die_holder.add_child(visual)

    var glow := TextureRect.new()
    glow.texture = _get_glow_texture()
    glow.material = _get_additive_material()
    glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.size = Vector2(GLOW_SIZE, GLOW_SIZE)
    glow.position = (DIE_HOLDER_SIZE - glow.size) / 2.0
    glow.pivot_offset = glow.size / 2.0
    glow.modulate = Color(accent.r, accent.g, accent.b, 0.5)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual.add_child(glow)

    var die := TextureRect.new()
    # Not always "6": Green is a d3, Even/Odd cap at 8/7, Giant shows its new 12 (see
    # DiceInfusions.preview_face) - loading %s6.png for green would fail outright.
    die.texture = load("res://assets/images/%s%d.png" % [dice_type, DiceInfusions.preview_face(dice_type)])
    die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    die.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    die.size = Vector2(DIE_SIZE, DIE_SIZE)
    die.position = (DIE_HOLDER_SIZE - die.size) / 2.0
    die.pivot_offset = die.size / 2.0
    die.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual.add_child(die)

    # Slow breathing pulse on the halo - killed on confirm so the ceremony owns it.
    var pulse := create_tween().set_loops()
    pulse.tween_property(glow, "scale", Vector2(1.08, 1.08), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    pulse.parallel().tween_property(glow, "modulate:a", 0.68, 1.5)
    pulse.tween_property(glow, "scale", Vector2(0.95, 0.95), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    pulse.parallel().tween_property(glow, "modulate:a", 0.45, 1.5)
    _pulse_tweens[dice_type] = pulse

    # Rising accent motes - "power seeping into the die".
    var mote_timer := Timer.new()
    mote_timer.wait_time = MOTE_INTERVAL
    mote_timer.autostart = true
    mote_timer.timeout.connect(_spawn_mote.bind(visual, accent))
    visual.add_child(mote_timer)

    # What it becomes: "ARCANE DICE" in the infused accent.
    var name_label := Label.new()
    name_label.text = String(info["name"]).to_upper()
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var name_settings := LabelSettings.new()
    name_settings.font = FONT_CHUNKY
    name_settings.font_size = 30
    name_settings.font_color = accent
    name_settings.outline_size = 7
    name_settings.outline_color = info["outline"]
    name_settings.shadow_size = 5
    name_settings.shadow_color = Color(0, 0, 0, 0.6)
    name_settings.shadow_offset = Vector2(2, 3)
    name_label.label_settings = name_settings
    vbox.add_child(name_label)

    var desc_label := Label.new()
    desc_label.text = info["description"]
    desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_label.custom_minimum_size = Vector2(300, 0)
    desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var desc_settings := LabelSettings.new()
    desc_settings.font = FONT_BODY
    desc_settings.font_size = 16
    desc_settings.font_color = CREAM
    desc_settings.shadow_size = 3
    desc_settings.shadow_color = Color(0, 0, 0, 0.6)
    desc_label.label_settings = desc_settings
    vbox.add_child(desc_label)

    _panels[dice_type] = panel
    _glows[dice_type] = glow
    _dies[dice_type] = die
    return panel


func _play_entrance() -> void:
    title_label.modulate.a = 0.0
    subtitle_label.modulate.a = 0.0
    infuse_button.modulate.a = 0.0
    for t: String in _panels:
        (_panels[t] as Control).modulate.a = 0.0

    # Wait one frame so containers have laid out and sizes/pivots are real.
    await get_tree().process_frame
    title_label.pivot_offset = title_label.size / 2.0
    title_label.scale = Vector2(1.3, 1.3)
    for t: String in _panels:
        var panel: Control = _panels[t]
        panel.pivot_offset = panel.size / 2.0

    var intro := create_tween()
    intro.tween_property(title_label, "modulate:a", 1.0, 0.25)
    intro.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    intro.tween_property(subtitle_label, "modulate:a", 1.0, 0.3)
    for t: String in _panels:
        var panel: Control = _panels[t]
        intro.tween_interval(0.15)
        intro.tween_property(panel, "modulate:a", 1.0, 0.3)
        intro.parallel().tween_callback(_pop_die.bind(t))
    intro.tween_property(infuse_button, "modulate:a", 1.0, 0.25)


func _pop_die(dice_type: String) -> void:
    var die: TextureRect = _dies[dice_type]
    die.scale = Vector2(0.55, 0.55)
    die.modulate = Color(1.9, 1.9, 1.9)
    var pop := create_tween()
    pop.tween_property(die, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pop.parallel().tween_property(die, "modulate", Color.WHITE, 0.32)


func _spawn_mote(parent: Control, accent: Color) -> void:
    if _confirmed:
        return
    var mote := TextureRect.new()
    mote.texture = _get_glow_texture()
    mote.material = _get_additive_material()
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_SCALE
    var mote_size := randf_range(10.0, 22.0)
    mote.size = Vector2(mote_size, mote_size)
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.modulate = Color(accent.r, accent.g, accent.b, 0.0)
    mote.position = Vector2(
        randf_range(15.0, DIE_HOLDER_SIZE.x - 15.0 - mote_size),
        DIE_HOLDER_SIZE.y - randf_range(5.0, 45.0)
    )
    parent.add_child(mote)

    var rise := randf_range(70.0, 120.0)
    var duration := randf_range(1.1, 1.7)
    var peak_alpha := randf_range(0.35, 0.6)
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(mote, "position:y", mote.position.y - rise, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.tween_property(mote, "position:x", mote.position.x + randf_range(-18.0, 18.0), duration)
    t.tween_property(mote, "modulate:a", peak_alpha, duration * 0.3)
    t.tween_property(mote, "modulate:a", 0.0, duration * 0.45).set_delay(duration * 0.55)
    t.chain().tween_callback(mote.queue_free)


func _on_panel_gui_input(event: InputEvent, dice_type: String) -> void:
    if _confirmed:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _select(dice_type)


func _on_panel_hover(dice_type: String, entered: bool) -> void:
    if _confirmed:
        return
    _hovered_type = dice_type if entered else ""
    _refresh_panel_visuals()


func _select(dice_type: String) -> void:
    if _selected_type == dice_type:
        return
    _selected_type = dice_type
    SFXPlayer.play(Global.sfx_click)
    _refresh_panel_visuals()

    var panel: Control = _panels[dice_type]
    var punch := create_tween()
    punch.tween_property(panel, "scale", Vector2(1.045, 1.045), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    punch.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    infuse_button.disabled = false


func _refresh_panel_visuals() -> void:
    for t: String in _panels:
        var panel: PanelContainer = _panels[t]
        var info: Dictionary = DiceInfusions.get_info(t)
        if t == _selected_type:
            panel.add_theme_stylebox_override("panel", _make_panel_style(info["accent"], true))
            panel.modulate = Color.WHITE
        elif t == _hovered_type:
            panel.add_theme_stylebox_override("panel", _make_panel_style(GOLD.lightened(0.25), true))
            panel.modulate = Color.WHITE
        else:
            panel.add_theme_stylebox_override("panel", _make_panel_style(GOLD, false))
            panel.modulate = Color.WHITE if _selected_type == "" else Color(0.62, 0.62, 0.62)


func _on_infuse_pressed() -> void:
    if _confirmed or _selected_type == "":
        return
    _confirmed = true
    infuse_button.disabled = true
    infuse_button.visible = false

    var info: Dictionary = DiceInfusions.get_info(_selected_type)
    # Lock the pick in immediately - state first, flourish after (same principle as the
    # Power number updating before its orbs land).
    Global.dice_infusions[_selected_type] = info["id"]

    SFXPlayer.play(INFUSE_SOUND)

    # The unpicked option bows out. Alpha only - its position belongs to the HBox.
    for t: String in _panels:
        if t == _selected_type:
            continue
        var fade := create_tween()
        fade.tween_property(_panels[t], "modulate:a", 0.0, 0.35)

    if _pulse_tweens.has(_selected_type):
        (_pulse_tweens[_selected_type] as Tween).kill()

    var glow: TextureRect = _glows[_selected_type]
    var die: TextureRect = _dies[_selected_type]

    # Gather -> detonate -> settle. The detonation callback adds the screen flash +
    # hit-stop at the exact moment the die blows up.
    var ceremony := create_tween()
    ceremony.tween_property(glow, "scale", Vector2(0.6, 0.6), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    ceremony.parallel().tween_property(glow, "modulate:a", 0.25, 0.22)
    ceremony.parallel().tween_property(die, "scale", Vector2(0.9, 0.9), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    ceremony.tween_callback(_ceremony_detonate)
    ceremony.tween_property(glow, "scale", Vector2(2.1, 2.1), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    ceremony.parallel().tween_property(glow, "modulate:a", 0.95, 0.1)
    ceremony.parallel().tween_property(die, "scale", Vector2(1.35, 1.35), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    ceremony.parallel().tween_property(die, "modulate", Color(2.0, 2.0, 2.0), 0.12)
    ceremony.tween_property(die, "modulate", Color.WHITE, 0.35)
    # Settle back to 1.0 - anything bigger leaves the die overlapping the name label below.
    ceremony.parallel().tween_property(die, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    ceremony.parallel().tween_property(glow, "modulate:a", 0.65, 0.4)
    ceremony.parallel().tween_property(glow, "scale", Vector2(1.35, 1.35), 0.4)
    ceremony.tween_interval(0.6)
    ceremony.tween_callback(func() -> void: Events.dice_infusion_completed.emit())


func _ceremony_detonate() -> void:
    Shaker.hit_stop(0.12)
    var flash := ColorRect.new()
    flash.color = Color(1, 1, 1, 0.0)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(flash)
    flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    var t := create_tween()
    t.tween_property(flash, "color:a", 0.5, 0.06)
    t.tween_property(flash, "color:a", 0.0, 0.45)
    t.tween_callback(flash.queue_free)


static func _get_glow_texture() -> Texture2D:
    if _glow_texture == null:
        var gradient := Gradient.new()
        gradient.set_color(0, Color(1, 1, 1, 1))
        gradient.set_color(1, Color(1, 1, 1, 0))
        gradient.add_point(0.55, Color(1, 1, 1, 0.35))
        var tex := GradientTexture2D.new()
        tex.gradient = gradient
        tex.fill = GradientTexture2D.FILL_RADIAL
        tex.fill_from = Vector2(0.5, 0.5)
        tex.fill_to = Vector2(0.5, 0.0)
        tex.width = 256
        tex.height = 256
        _glow_texture = tex
    return _glow_texture


static func _get_additive_material() -> CanvasItemMaterial:
    if _additive_material == null:
        var mat := CanvasItemMaterial.new()
        mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        _additive_material = mat
    return _additive_material
