extends Control

@onready var enable_tutorial_panel: Panel = $EnableTutorialPanel
@onready var load_run_button: Button = $LoadRun
@onready var new_run_button: Button = $NewRun
@onready var load_run_confirm_panel: Panel = $LoadRunConfirmPanel
@onready var load_run_confirm_subtitle: Label = $LoadRunConfirmPanel/SubtitleLabel
@onready var load_run_stats: PanelContainer = $LoadRunConfirmPanel/RunStats
@onready var settings_button: TextureButton = %SettingsButton
@onready var settings_button_hover_glow: Panel = get_node("%SettingsButton/SettingsHoverGlow")
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var background: TextureRect = $Background
@onready var discord_control: Control = $JoinDiscordControl
@onready var version_label: Label = $VersionLabel


const RUN_SCENE := preload("res://scenes/run/run.tscn")

func _ready()  -> void:
    var main_menu_theme = preload("res://main_menu_theme_v2.ogg")
    SFXPlayer.play(main_menu_theme)
    get_tree().paused = false
    # Load Run only shown when a run save actually exists. Both buttons share the
    # same ornate menu-button style (main_menu.tscn) - the background art itself
    # (menu_bg_dawn.png) no longer has any button or logo painted into it.
    load_run_button.visible = SaveManager.has_save()
    # Version stamp - single source of truth is application/config/version in
    # project.godot; the .tscn text is only an editor placeholder.
    $VersionLabel.text = "v%s" % ProjectSettings.get_setting("application/config/version", "?")
    _build_menu_scene()
    _play_entrance()


# Reads the save straight from disk instead of trusting has_save() alone (which
# only checks the file exists) - read_save() also rejects a corrupted or
# version-mismatched file, returning {}. That case falls through to run.gd's own
# fallback (_load_run starts a fresh run if the save is unusable), so skip the
# confirmation screen entirely and go straight to the load flow.
func _on_load_run_pressed() -> void:
    var data := SaveManager.read_save()
    if data.is_empty():
        _start_load_run()
        return
    _populate_load_confirm_panel(data)
    _show_load_confirm_panel()


func _populate_load_confirm_panel(data: Dictionary) -> void:
    var act: int = data.get("act", 1)
    var floors_climbed: int = data.get("map", {}).get("floors_climbed", 0)
    var floor_in_act: int = mini(floors_climbed + 1, MapGenerator.FLOORS)
    # Same act-offset numbering as the top bar's Floor label (act 2 continues the
    # count instead of restarting at 1).
    var global_floor: int = (act - 1) * MapGenerator.FLOORS + floor_in_act
    var total_dice := 0
    for amount: int in data.get("dice_max", {}).values():
        total_dice += amount

    load_run_confirm_subtitle.text = "Act %d  ·  Floor %d" % [act, global_floor]
    load_run_stats.build_rows([
        {"label": "Gold", "icon": "res://gold_icon_v2.png", "value": int(data.get("gold", 0))},
        {"label": "Health", "icon": "res://assets/images/heart.png", "text": "%d / %d" % [int(data.get("health", 0)), int(data.get("max_health", 0))]},
        {"label": "Cards in Deck", "icon": "res://card_cover_icon.png", "value": data.get("deck", []).size()},
        {"label": "Relics", "icon": "res://crown.png", "value": data.get("relics", []).size()},
        {"label": "Dice Owned", "icon": "res://assets/images/blue6.png", "value": total_dice},
    ])


const LOAD_PANEL_ENTRANCE_TIME := 0.3
const LOAD_PANEL_STATS_DELAY := 0.15

# Same settle-in pop + staggered scoreboard reveal beat as the end-of-run screens.
func _show_load_confirm_panel() -> void:
    load_run_confirm_panel.show()
    load_run_confirm_panel.pivot_offset = load_run_confirm_panel.size / 2.0
    load_run_confirm_panel.modulate.a = 0.0
    load_run_confirm_panel.scale = Vector2(0.94, 0.94)
    var tween := create_tween()
    tween.tween_property(load_run_confirm_panel, "modulate:a", 1.0, LOAD_PANEL_ENTRANCE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(load_run_confirm_panel, "scale", Vector2.ONE, LOAD_PANEL_ENTRANCE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_interval(LOAD_PANEL_STATS_DELAY)
    tween.tween_callback(load_run_stats.animate_in)


func _on_confirm_load_pressed() -> void:
    load_run_confirm_panel.hide()
    _start_load_run()


func _on_cancel_load_pressed() -> void:
    load_run_confirm_panel.hide()


func _start_load_run() -> void:
    # Consumed by run.gd::_late_init, which restores from SaveManager instead of
    # starting fresh. tutorial_on comes back from the save itself, so no tutorial
    # popup on this path.
    Global.load_run_requested = true
    var new_run_sound = preload("res://success.mp3")
    SFXPlayer.stop()
    SFXPlayer.play(new_run_sound)
    await get_tree().create_timer(new_run_sound.get_length()).timeout
    get_tree().change_scene_to_packed(RUN_SCENE)

func _on_new_run_pressed() -> void:
    enable_tutorial_panel.show()


func _on_cancel_tutorial_panel_pressed() -> void:
    enable_tutorial_panel.hide()


func _on_start_with_tutorial_pressed() -> void:
    Global.tutorial_on = true
    var new_run_sound = preload("res://success.mp3")
    SFXPlayer.stop()
    SFXPlayer.play(new_run_sound)
    await get_tree().create_timer(new_run_sound.get_length()).timeout
    get_tree().change_scene_to_packed(RUN_SCENE)


func _on_start_without_tutorial_pressed() -> void:
    Global.tutorial_on = false
    var new_run_sound = preload("res://success.mp3")
    SFXPlayer.stop()
    SFXPlayer.play(new_run_sound)
    await get_tree().create_timer(new_run_sound.get_length()).timeout
    get_tree().change_scene_to_packed(RUN_SCENE)


func _on_discord_button_pressed() -> void:
    OS.shell_open("https://discord.gg/fah8A2qQx2")


func _on_settings_button_pressed() -> void:
    pause_menu.toggle()


# Same hover-glow treatment as the in-run gear button (run.gd::_on_pause_button_*).
func _on_settings_button_mouse_entered() -> void:
    settings_button.modulate = Color(1.18, 1.18, 1.18)
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(settings_button_hover_glow, "modulate:a", 1.0, 0.12)


func _on_settings_button_mouse_exited() -> void:
    settings_button.modulate = Color.WHITE
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(settings_button_hover_glow, "modulate:a", 0.0, 0.12)


# =====================================================================================
# DAWN MENU SCENE (2026-08-30) - the layered, animated main menu.
#
# The old menu was one flat painting (main_menu_v4.png, logo baked in) with zero
# motion. This build layers it: dawn landscape plate (drifts + mouse parallax) ->
# two 3/4 dice resting on the painted ritual circle, wearing live additive halos and
# rising motes -> extracted logo with a periodic gold light-sweep -> the existing
# buttons/panels untouched on top.
#
# Rules baked in from the project's VFX lessons:
#  - all new art is load()ed at runtime and null-guarded, never preload()ed - a stale
#    import cache must degrade the menu, not kill the whole script (documented trap).
#  - breathing is sine-in-_process with golden-ratio phases, never looped tweens.
#  - parallax moves LAYER nodes, while tweens (drop, hop) animate the dice inside
#    their layer - the two never write the same property.
#  - dice glows use the canonical DicePalette glow recipe (accent colors follow any
#    future palette change for free).
# =====================================================================================

const MENU_LOGO_PATH := "res://assets/images/ui/menu_logo.png"
const MENU_DIE_BLUE_PATH := "res://assets/images/ui/menu_die_blue.png"
const MENU_DIE_RED_PATH := "res://assets/images/ui/menu_die_red.png"
const MENU_THUD_PATH := "res://sounds/dicerollsound3.mp3"
const MENU_PLUCK_PATH := "res://sfx/578807__nomiqbomi__pluck-1.mp3"

# Layout (design space 1280x720). The plate is 1376x768 drawn 1:1, centered with
# +-48/+-24 px hanging off every edge - drift + parallax must stay well inside that.
const PLATE_BASE_POS := Vector2(-48, -24)
const PLATE_DRIFT := Vector2(7.0, 4.0)
const PLATE_SUN_LOCAL := Vector2(1128, 218)  # sun centre, in plate pixels
const LOGO_POS := Vector2(58, 25)
const LOGO_WIDTH := 428.0
# V1 "cast on the circle": near die big and low, far die smaller and higher.
const BLUE_DIE_CENTER := Vector2(557, 572)
const BLUE_DIE_WIDTH := 173.0
const RED_DIE_CENTER := Vector2(723, 515)
const RED_DIE_WIDTH := 134.0
const DIE_HALO_SCALE := 2.6
# Two-layer glow per die (wide wash + tight core) - a single wide additive halo
# reads as almost nothing on plate D's bright platform. The glow texture's soft
# falloff thins the energy fast, so these run hot: overbright rgb (>1 modulate,
# the established trick) plus high alphas measured against a render, not guessed.
const HALO_BASE_ALPHA := [0.9, 0.85]
const HALO_CORE_ALPHA := [0.85, 0.8]
const HALO_OVERBRIGHT := 1.35
const HALO_WHITE_LIFT := [0.15, 0.28]
# Soft local darkening under each die (normal blend) - gives the additive light
# darker ground to stand on, same trick as the combat background dim.
const UNDER_DIM_ALPHA := 0.34
# How far each die's motes are lifted toward white - crimson needs more than
# cobalt to survive additive blending over the warm bright path.
const MOTE_WHITE_LIFT := [0.35, 0.5]
# Camera-pan parallax: every layer moves opposite the mouse, foreground most.
const PARALLAX_PLATE := 4.0
const PARALLAX_DICE := 8.5
const PARALLAX_LOGO := 1.5

const ENTRANCE_COVER_FADE := 0.7
const ENTRANCE_LOGO_AT := 0.35
const ENTRANCE_BLUE_DROP_AT := 0.85
const ENTRANCE_RED_DROP_AT := 1.1
const ENTRANCE_BUTTONS_AT := 1.55
const ENTRANCE_DONE_AT := 1.95
const DIE_DROP_HEIGHT := 240.0
const DIE_DROP_TIME := 0.3

const HOP_INTERVAL_MIN := 8.0
const HOP_INTERVAL_MAX := 14.0
const SWEEP_INTERVAL_MIN := 9.0
const SWEEP_INTERVAL_MAX := 13.0

var _menu_time := 0.0
var _entrance_done := false
var _parallax_current := Vector2.ZERO
var _scene_layer: Control
var _logo_layer: Control
var _logo: TextureRect
var _logo_material: ShaderMaterial
var _sun_glow: TextureRect
var _dice: Array[TextureRect] = []
var _halos: Array[TextureRect] = []
var _halo_cores: Array[TextureRect] = []
var _under_dims: Array[TextureRect] = []
var _shadows: Array[TextureRect] = []
var _die_hopping := [false, false]
var _halo_on := [false, false]
var _halo_ramp := [0.0, 0.0]
var _mote_clock := [0.0, 0.0]
var _mote_next := [0.5, 0.8]
var _next_hop_at := 0.0
var _next_sweep_at := 0.0
var _cta_hovered := false
var _cta_flare := 0.0


func _build_menu_scene() -> void:
    # Warm breathing glow pinned on the painted sun - parented to the plate so it
    # drifts with the painting instead of sliding across it.
    _sun_glow = _make_glow_rect(360.0, Color(1.0, 0.82, 0.55, 0.16))
    _sun_glow.position = PLATE_SUN_LOCAL - Vector2(180, 180)
    background.add_child(_sun_glow)

    # Dice layer - moved as a whole for parallax; the dice tween their own local
    # position (drop/hop) inside it, so the two motions never fight.
    _scene_layer = Control.new()
    _scene_layer.name = "MenuSceneLayer"
    _scene_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    _scene_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_scene_layer)
    move_child(_scene_layer, background.get_index() + 1)

    var die_textures: Array[Texture2D] = []
    die_textures.append(load(MENU_DIE_BLUE_PATH) as Texture2D)
    die_textures.append(load(MENU_DIE_RED_PATH) as Texture2D)
    var centers := [BLUE_DIE_CENTER, RED_DIE_CENTER]
    var widths := [BLUE_DIE_WIDTH, RED_DIE_WIDTH]
    var accents := [DicePalette.accent("blue"), DicePalette.accent("red")]

    for i in 2:
        var tex: Texture2D = die_textures[i]
        if tex == null:
            continue
        var center: Vector2 = centers[i]
        var w: float = widths[i]
        var h: float = w * float(tex.get_height()) / float(tex.get_width())
        var accent: Color = accents[i]

        # Soft contact shadow under the die's resting corner.
        var shadow := _make_glow_rect(w * 1.15, Color(0, 0, 0, 0.5), false)
        shadow.size = Vector2(w * 1.15, w * 0.30)
        shadow.pivot_offset = shadow.size / 2.0
        shadow.position = Vector2(center.x - shadow.size.x / 2.0, center.y + h / 2.0 - 4.0 - shadow.size.y / 2.0)
        _scene_layer.add_child(shadow)
        _shadows.append(shadow)

        var under_dim := _make_glow_rect(w * 3.0, Color(0.03, 0.03, 0.08, UNDER_DIM_ALPHA), false)
        under_dim.position = center - under_dim.size / 2.0
        _scene_layer.add_child(under_dim)
        _under_dims.append(under_dim)

        var halo_color: Color = accent.lerp(Color.WHITE, HALO_WHITE_LIFT[i]) * HALO_OVERBRIGHT
        halo_color.a = HALO_BASE_ALPHA[i]
        var halo := _make_glow_rect(w * DIE_HALO_SCALE, halo_color)
        halo.position = center - halo.size / 2.0
        halo.pivot_offset = halo.size / 2.0
        _scene_layer.add_child(halo)
        _halos.append(halo)

        var core_color: Color = accent.lerp(Color.WHITE, 0.45) * HALO_OVERBRIGHT
        core_color.a = HALO_CORE_ALPHA[i]
        var core := _make_glow_rect(w * 1.35, core_color)
        core.position = center - core.size / 2.0
        core.pivot_offset = core.size / 2.0
        _scene_layer.add_child(core)
        _halo_cores.append(core)

        var die := TextureRect.new()
        die.texture = tex
        die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        die.stretch_mode = TextureRect.STRETCH_SCALE
        die.size = Vector2(w, h)
        die.position = center - die.size / 2.0
        # Squash pivots on the resting corner, so landings squish onto the stone.
        die.pivot_offset = Vector2(die.size.x / 2.0, die.size.y * 0.95)
        die.mouse_filter = Control.MOUSE_FILTER_STOP
        die.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        die.gui_input.connect(_on_die_gui_input.bind(i))
        _scene_layer.add_child(die)
        _dice.append(die)

    # Logo in its own parallax layer; the logo node itself keeps its entrance tween.
    _logo_layer = Control.new()
    _logo_layer.name = "MenuLogoLayer"
    _logo_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    _logo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_logo_layer)
    move_child(_logo_layer, _scene_layer.get_index() + 1)
    var logo_tex: Texture2D = load(MENU_LOGO_PATH) as Texture2D
    if logo_tex != null:
        _logo = TextureRect.new()
        _logo.texture = logo_tex
        _logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        _logo.stretch_mode = TextureRect.STRETCH_SCALE
        _logo.size = Vector2(LOGO_WIDTH, LOGO_WIDTH * float(logo_tex.get_height()) / float(logo_tex.get_width()))
        _logo.position = LOGO_POS
        _logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _logo_material = _build_logo_sweep_material()
        _logo.material = _logo_material
        _logo_layer.add_child(_logo)

    ButtonFeel.attach(new_run_button)
    ButtonFeel.attach(load_run_button)
    new_run_button.mouse_entered.connect(_on_new_run_hover_entered)
    new_run_button.mouse_exited.connect(_on_new_run_hover_exited)
    load_run_button.mouse_entered.connect(_play_hover_pluck)


func _make_glow_rect(width: float, color: Color, additive: bool = true) -> TextureRect:
    var rect := TextureRect.new()
    rect.texture = DicePalette.glow_texture()
    # A black modulate on an additive blend adds nothing at all - the contact
    # shadows stay on normal blend (soft radial alpha tinted black).
    if additive:
        rect.material = DicePalette.additive_material()
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_SCALE
    rect.size = Vector2(width, width)
    rect.modulate = color
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rect


# Diagonal specular band that only brightens where the logo has ink. Built from a
# code string (like enemy.gd's wipe shader) so a stale import cache can't turn a
# .gdshader file into a parse error.
func _build_logo_sweep_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
uniform float band_center = -0.6;
uniform float band_width = 0.16;
uniform float strength = 0.55;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float d = abs(UV.x + UV.y * 0.35 - band_center);
    float band = smoothstep(band_width, 0.0, d);
    tex.rgb += band * strength * tex.a;
    COLOR = tex;
}
"""
    var mat := ShaderMaterial.new()
    mat.shader = shader
    # Seed every uniform once - an unassigned shader param can't be tweened and
    # reads back null (documented trap).
    mat.set_shader_parameter("band_center", -0.6)
    mat.set_shader_parameter("band_width", 0.16)
    mat.set_shader_parameter("strength", 0.55)
    return mat


func _play_entrance() -> void:
    # Pre-state: everything invisible, buttons shifted left.
    for die in _dice:
        die.modulate.a = 0.0
    for halo in _halos:
        halo.modulate.a = 0.0
    for core in _halo_cores:
        core.modulate.a = 0.0
    for dim in _under_dims:
        dim.modulate.a = 0.0
    for shadow in _shadows:
        shadow.modulate.a = 0.0
    if _logo != null:
        _logo.modulate.a = 0.0
    for btn: Button in [new_run_button, load_run_button]:
        btn.modulate.a = 0.0
        btn.position.x -= 90.0
    discord_control.modulate.a = 0.0
    settings_button.modulate.a = 0.0
    version_label.modulate.a = 0.0

    var cover := ColorRect.new()
    cover.color = Color.BLACK
    cover.set_anchors_preset(Control.PRESET_FULL_RECT)
    cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(cover)
    var cover_tween := create_tween()
    cover_tween.tween_property(cover, "modulate:a", 0.0, ENTRANCE_COVER_FADE).from(1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    cover_tween.tween_callback(cover.queue_free)

    _delay_call(ENTRANCE_LOGO_AT, _enter_logo)
    _delay_call(ENTRANCE_BLUE_DROP_AT, _drop_die.bind(0))
    _delay_call(ENTRANCE_RED_DROP_AT, _drop_die.bind(1))
    _delay_call(ENTRANCE_BUTTONS_AT, _enter_buttons)
    _delay_call(ENTRANCE_DONE_AT, _finish_entrance)


func _delay_call(delay: float, cb: Callable) -> void:
    get_tree().create_timer(delay).timeout.connect(cb, CONNECT_ONE_SHOT)


func _enter_logo() -> void:
    if _logo == null:
        return
    var tween := create_tween()
    tween.tween_property(_logo, "modulate:a", 1.0, 0.45).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(_logo, "position:y", LOGO_POS.y, 0.45).from(LOGO_POS.y - 16.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _drop_die(i: int) -> void:
    if i >= _dice.size():
        return
    var die := _dice[i]
    var rest_y := die.position.y
    die.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_property(die, "position:y", rest_y, DIE_DROP_TIME).from(rest_y - DIE_DROP_HEIGHT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_callback(_land_die.bind(i, true))
    if i < _shadows.size():
        var sh_tween := create_tween()
        sh_tween.tween_property(_shadows[i], "modulate:a", 0.5, DIE_DROP_TIME).from(0.0)


func _land_die(i: int, first_landing: bool) -> void:
    if i >= _dice.size():
        return
    var die := _dice[i]
    var tween := create_tween()
    tween.tween_property(die, "scale", Vector2(1.14, 0.84), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(die, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    if first_landing:
        # The halo is ramped up by _process (which owns halo alpha every frame for
        # the breathing) - a fade tween here would fight it on the same property.
        _halo_on[i] = true
        var thud: AudioStream = load(MENU_THUD_PATH) as AudioStream
        SFXPlayer.play(thud, false, 0.74 + i * 0.08, -4.0)
        _burst_motes(i, 7)
    else:
        var clack: AudioStream = load(MENU_THUD_PATH) as AudioStream
        SFXPlayer.play(clack, false, 1.25, -13.0, -1)
        _burst_motes(i, 3)


func _enter_buttons() -> void:
    var delay := 0.0
    for btn: Button in [new_run_button, load_run_button]:
        var target_x := btn.position.x + 90.0
        var tween := create_tween()
        tween.tween_interval(delay)
        tween.tween_property(btn, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(btn, "position:x", target_x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        delay += 0.12
    var chrome_tween := create_tween()
    chrome_tween.tween_property(discord_control, "modulate:a", 1.0, 0.4)
    chrome_tween.parallel().tween_property(settings_button, "modulate:a", 1.0, 0.4)
    chrome_tween.parallel().tween_property(version_label, "modulate:a", 1.0, 0.4)


func _finish_entrance() -> void:
    _entrance_done = true
    _next_hop_at = _menu_time + 5.0
    _next_sweep_at = _menu_time + 2.0


func _process(delta: float) -> void:
    _menu_time += delta

    # Mouse parallax, smoothed - every layer slides opposite the cursor.
    var viewport_size := get_viewport_rect().size
    var mouse := get_viewport().get_mouse_position()
    var normalized := Vector2.ZERO
    if viewport_size.x > 0 and viewport_size.y > 0:
        normalized = (mouse - viewport_size / 2.0) / (viewport_size / 2.0)
        normalized = normalized.clamp(Vector2(-1, -1), Vector2(1, 1))
    _parallax_current = _parallax_current.lerp(normalized, 1.0 - exp(-4.0 * delta))

    if background != null:
        var drift := Vector2(
            sin(_menu_time * TAU / 47.0) * PLATE_DRIFT.x,
            sin(_menu_time * TAU / 61.0 + 1.3) * PLATE_DRIFT.y)
        background.position = PLATE_BASE_POS + drift + _parallax_current * -PARALLAX_PLATE
    if _scene_layer != null:
        _scene_layer.position = _parallax_current * -PARALLAX_DICE
    if _logo_layer != null:
        _logo_layer.position = _parallax_current * -PARALLAX_LOGO

    # CTA flare: hovering Start New Run makes the dice answer.
    var flare_target := 1.0 if _cta_hovered else 0.0
    _cta_flare = lerpf(_cta_flare, flare_target, 1.0 - exp(-6.0 * delta))

    # Halo breathing - golden-ratio phases so the two dice never sync up. _process
    # owns halo alpha exclusively; the post-landing fade-in is the ramp below.
    for i in _halos.size():
        if _halo_on[i]:
            _halo_ramp[i] = minf(float(_halo_ramp[i]) + delta * 2.5, 1.0)
            var ramp: float = _halo_ramp[i]
            var phase := TAU * 0.618 * i
            var breath := 0.82 + 0.18 * sin(_menu_time * TAU / (3.1 + 0.6 * i) + phase)
            var flare_mult := 1.0 + _cta_flare * 0.7
            _halos[i].modulate.a = HALO_BASE_ALPHA[i] * breath * flare_mult * ramp
            if i < _halo_cores.size():
                _halo_cores[i].modulate.a = HALO_CORE_ALPHA[i] * breath * flare_mult * ramp
            if i < _under_dims.size():
                _under_dims[i].modulate.a = UNDER_DIM_ALPHA * ramp
            var s := 1.0 + 0.04 * sin(_menu_time * TAU / (4.3 + 0.7 * i) + phase)
            _halos[i].scale = Vector2(s, s)
            if i < _halo_cores.size():
                _halo_cores[i].scale = Vector2(s, s)

    if _sun_glow != null:
        _sun_glow.modulate.a = 0.13 + 0.05 * sin(_menu_time * 0.9) + 0.03 * sin(_menu_time * 2.3 + 1.7)

    if _entrance_done:
        for i in _dice.size():
            var rate := 2.0 if _cta_flare > 0.5 else 1.0
            _mote_clock[i] += delta * rate
            if _mote_clock[i] >= _mote_next[i]:
                _mote_clock[i] = 0.0
                _mote_next[i] = randf_range(0.55, 0.9)
                _spawn_mote(i)
        if _menu_time >= _next_hop_at:
            _next_hop_at = _menu_time + randf_range(HOP_INTERVAL_MIN, HOP_INTERVAL_MAX)
            _hop_die(randi() % maxi(_dice.size(), 1), false)
        if _logo_material != null and _menu_time >= _next_sweep_at:
            _next_sweep_at = _menu_time + randf_range(SWEEP_INTERVAL_MIN, SWEEP_INTERVAL_MAX)
            var sweep := create_tween()
            sweep.tween_property(_logo_material, "shader_parameter/band_center", 1.6, 1.0).from(-0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


const DIE_ACCENT_TYPES := ["blue", "red"]

func _spawn_mote(i: int) -> void:
    if i >= _dice.size() or _scene_layer == null:
        return
    var die := _dice[i]
    var accent := DicePalette.accent(DIE_ACCENT_TYPES[i])
    var mote_size := randf_range(10.0, 20.0)
    var mote := _make_glow_rect(mote_size, Color(accent.lerp(Color.WHITE, MOTE_WHITE_LIFT[i]), randf_range(0.5, 0.75)))
    var start := die.position + Vector2(
        die.size.x * randf_range(0.1, 0.9),
        die.size.y * randf_range(-0.1, 0.4))
    mote.position = start - mote.size / 2.0
    _scene_layer.add_child(mote)
    var life := randf_range(1.3, 1.9)
    var tween := mote.create_tween()
    tween.tween_property(mote, "position:y", mote.position.y - randf_range(90.0, 150.0), life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(mote, "position:x", mote.position.x + randf_range(-14.0, 14.0), life)
    tween.parallel().tween_property(mote, "modulate:a", 0.0, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.tween_callback(mote.queue_free)


func _burst_motes(i: int, count: int) -> void:
    for _j in count:
        _spawn_mote(i)


# Small restless jump - scheduled occasionally on its own, bigger when poked.
func _hop_die(i: int, poked: bool) -> void:
    if i >= _dice.size() or _die_hopping[i]:
        return
    _die_hopping[i] = true
    var die := _dice[i]
    var rest_y := die.position.y
    var height := 22.0 if poked else 14.0
    var tween := create_tween()
    tween.tween_property(die, "position:y", rest_y - height, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(die, "position:y", rest_y, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_callback(_land_die.bind(i, false))
    tween.tween_callback(func() -> void: _die_hopping[i] = false)
    if i < _shadows.size():
        var shadow := _shadows[i]
        var sh_tween := create_tween()
        sh_tween.tween_property(shadow, "modulate:a", 0.32, 0.16)
        sh_tween.tween_property(shadow, "modulate:a", 0.5, 0.13)
    if poked:
        var flash_tween := create_tween()
        flash_tween.tween_property(die, "modulate", Color(1.55, 1.55, 1.55), 0.06)
        flash_tween.tween_property(die, "modulate", Color.WHITE, 0.24)
        _burst_motes(i, 5)


func _on_die_gui_input(event: InputEvent, i: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _hop_die(i, true)


func _on_new_run_hover_entered() -> void:
    _cta_hovered = true
    _play_hover_pluck()


func _on_new_run_hover_exited() -> void:
    _cta_hovered = false


func _play_hover_pluck() -> void:
    var pluck: AudioStream = load(MENU_PLUCK_PATH) as AudioStream
    SFXPlayer.play(pluck, false, randf_range(1.35, 1.5), -13.0, -1)
