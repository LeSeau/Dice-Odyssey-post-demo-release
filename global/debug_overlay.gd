extends CanvasLayer

# Debug-build A/B pickers (2026-08-25, Julien: "2 debug buttons ... accessible everywhere").
#
#   SFX  - cycles the MAX-ROLL landing smash, i.e. the "high roll" sound. Candidates are the
#          dicecrush1-5 files that have sat unreferenced in the repo since the card batch,
#          plus sound_high_roll.wav, plus anything dropped into res://debug_sfx_candidates/
#          crush (the folder dice.gd's F9 audition already used - F9 now drives THIS list, so
#          the shortcut and the button can no longer disagree about what is selected).
#   HERO - cycles the player sprite between the shipped art and whatever sits in
#          res://debug_hero_candidates (the four Telegram recolours of the current hero).
#
# Parented to the Global autoload rather than to any scene, so it draws above main menu, map,
# battle, shop and event alike and survives every scene change - "accessible everywhere"
# literally. Built 100% in code with NO class_name and NO new autoload entry, so nothing here
# needs the editor restarted or the global-script-class cache regenerated.
#
# Both selections live on Global: they survive scene reloads, are never written to the save
# file, and the layer is only ever constructed under OS.is_debug_build() - release builds
# never see any of this. Left click = next candidate, right click = previous.

# Under the relic bar (which ends at y=98) and above run.tscn's own DebugButtons column
# (which starts at y=258), so all three coexist without overlapping.
const PANEL_POSITION := Vector2(12, 106)
const BUTTON_MIN_WIDTH := 252.0
# A plain UI font on purpose: this must never be mistaken for shippable chrome, so it
# deliberately does NOT speak the game's Belwe/Cinzel typography.
const FONT_PATH := "res://Noto_Sans/static/NotoSans-Medium.ttf"
const FONT_SIZE := 11

# "" = the shipped default (Global.DEFAULT_HIGH_ROLL_SOUND).
const SFX_CANDIDATES: Array[String] = [
    "",
    "res://dicecrush1.mp3",
    "res://dicecrush2.mp3",
    "res://dicecrush3.mp3",
    "res://dicecrush4.mp3",
    "res://dicecrush5.mp3",
    "res://sound_high_roll.wav",
]
const SFX_CANDIDATE_DIR := "res://debug_sfx_candidates/crush"
# Scanned rather than hardcoded so dropping a fifth/sixth recolour in just works. The debug_*
# name rides the web export's exclude_filter, so none of it can ever ship.
const HERO_CANDIDATE_DIR := "res://debug_hero_candidates"

var _sfx_paths: Array[String] = []
var _hero_paths: Array[String] = []
var _sfx_index := 0
var _hero_index := 0
var _sfx_button: Button
var _hero_button: Button
var _collapse_button: Button


func _ready() -> void:
    layer = 95  # above the achievement toast (90), the pause menu (60) and every battle layer
    # ALWAYS so the buttons still work while the tree is paused - the pause menu, map consult
    # mode and the battle-over panel all pause it, and auditioning a sound from a paused
    # screen is exactly when you want to.
    process_mode = Node.PROCESS_MODE_ALWAYS

    for path: String in SFX_CANDIDATES:
        _sfx_paths.append(path)
    _sfx_paths.append_array(_scan_dir(SFX_CANDIDATE_DIR, [".ogg", ".wav", ".mp3"]))

    _hero_paths.append("")
    _hero_paths.append_array(_scan_dir(HERO_CANDIDATE_DIR, [".png", ".jpg", ".webp"]))

    _build_ui()
    _refresh_labels()


func _scan_dir(dir_path: String, extensions: Array) -> Array[String]:
    var found: Array[String] = []
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return found
    for file_name: String in dir.get_files():
        var lower := file_name.to_lower()
        for ext: String in extensions:
            if lower.ends_with(ext):
                found.append(dir_path + "/" + file_name)
                break
    found.sort()
    return found


func _build_ui() -> void:
    var font := load(FONT_PATH) as Font

    var panel := PanelContainer.new()
    panel.position = PANEL_POSITION
    panel.add_theme_stylebox_override("panel", _panel_stylebox())
    add_child(panel)

    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 6)
    panel.add_child(margin)

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 4)
    margin.add_child(body)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 6)
    body.add_child(header)

    var title := Label.new()
    title.text = "DEBUG"
    if font:
        title.add_theme_font_override("font", font)
    title.add_theme_font_size_override("font_size", FONT_SIZE - 1)
    title.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)

    _collapse_button = _make_button(font, 0.0)
    _collapse_button.text = "-"
    _collapse_button.pressed.connect(_toggle_collapsed)
    header.add_child(_collapse_button)

    _sfx_button = _make_button(font, BUTTON_MIN_WIDTH)
    _sfx_button.pressed.connect(_cycle_sfx.bind(1))
    _sfx_button.gui_input.connect(_on_button_gui_input.bind(_cycle_sfx))
    body.add_child(_sfx_button)

    _hero_button = _make_button(font, BUTTON_MIN_WIDTH)
    _hero_button.pressed.connect(_cycle_hero.bind(1))
    _hero_button.gui_input.connect(_on_button_gui_input.bind(_cycle_hero))
    body.add_child(_hero_button)


func _make_button(font: Font, min_width: float) -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(min_width, 0)
    button.focus_mode = Control.FOCUS_NONE  # never steal focus from the game underneath
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    if font:
        button.add_theme_font_override("font", font)
    button.add_theme_font_size_override("font_size", FONT_SIZE)
    button.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
    button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
    button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
    # All four states overridden, never just normal/hover: an un-overridden state falls back
    # to the project theme and pops a Cinzel-styled box mid-click (the dice-shop X-button bug).
    button.add_theme_stylebox_override("normal", _button_stylebox(Color(1, 1, 1, 0.08)))
    button.add_theme_stylebox_override("hover", _button_stylebox(Color(1, 1, 1, 0.18)))
    button.add_theme_stylebox_override("pressed", _button_stylebox(Color(1, 1, 1, 0.28)))
    button.add_theme_stylebox_override("focus", _button_stylebox(Color(1, 1, 1, 0.08)))
    return button


func _panel_stylebox() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.04, 0.05, 0.07, 0.82)
    style.border_color = Color(1, 1, 1, 0.22)
    style.set_border_width_all(1)
    style.set_corner_radius_all(4)
    return style


func _button_stylebox(bg: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.set_corner_radius_all(3)
    style.content_margin_left = 6.0
    style.content_margin_right = 6.0
    style.content_margin_top = 3.0
    style.content_margin_bottom = 3.0
    return style


# Right click = previous candidate. Godot fires `pressed` on left click only, so the backwards
# step has to come off raw gui_input - worth it for A/B-ing two adjacent takes instead of
# wrapping all the way round a seven-item list.
func _on_button_gui_input(event: InputEvent, cycler: Callable) -> void:
    var mouse := event as InputEventMouseButton
    if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_RIGHT:
        return
    cycler.call(-1)
    get_viewport().set_input_as_handled()


func _toggle_collapsed() -> void:
    _sfx_button.visible = not _sfx_button.visible
    _hero_button.visible = _sfx_button.visible
    _collapse_button.text = "-" if _sfx_button.visible else "+"


# Public so the F9 shortcut in dice.gd drives the same index this panel displays.
func cycle_sfx(step: int) -> void:
    _cycle_sfx(step)


func _cycle_sfx(step: int) -> void:
    _sfx_index = wrapi(_sfx_index + step, 0, _sfx_paths.size())
    var path := _sfx_paths[_sfx_index]
    if path.is_empty():
        Global.debug_high_roll_sound = null
    else:
        Global.debug_high_roll_sound = load(path) as AudioStream
    _refresh_labels()
    # Audition it straight away - the whole point is judging candidates without having to roll
    # a max in a real fight first.
    SFXPlayer.play(Global.high_roll_sound(), false, 1.0, -2.0)


func _cycle_hero(step: int) -> void:
    _hero_index = wrapi(_hero_index + step, 0, _hero_paths.size())
    var path := _hero_paths[_hero_index]
    if path.is_empty():
        Global.debug_player_texture = null
    else:
        Global.debug_player_texture = _load_texture(path)
    _refresh_labels()
    # Apply to the live hero if a battle is on screen; otherwise the next Player node picks it
    # up in Player.update_player(). apply_debug_texture() also rescales the swap to the shipped
    # art's on-screen size, so candidates authored on their own canvas still line up.
    if is_instance_valid(Global.player):
        Global.player.apply_debug_texture()


# Candidates get dropped in while the editor has a different project open, so they usually have
# no .import yet and load() would fail. Fall back to reading the raw file off disk - legal here
# because a debug build's res:// is a real folder.
func _load_texture(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        var resource := load(path)
        if resource is Texture2D:
            return resource
    var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
    if image != null:
        return ImageTexture.create_from_image(image)
    print("[debug-overlay] could not load %s" % path)
    return null


func _refresh_labels() -> void:
    _sfx_button.text = "SFX  %d/%d  %s" % [
            _sfx_index + 1, _sfx_paths.size(), _label_for(_sfx_paths[_sfx_index], "impact1")]
    _hero_button.text = "HERO %d/%d  %s" % [
            _hero_index + 1, _hero_paths.size(), _label_for(_hero_paths[_hero_index], "current")]


func _label_for(path: String, shipped_name: String) -> String:
    if path.is_empty():
        return "%s (shipped)" % shipped_name
    return path.get_file().get_basename()
