extends Control

# The run-identity picker ("the wish"): shown by run.gd at the start of every run from
# the player's SECOND run onward (AchievementManager "runs_started"), before the map
# appears. Five dice loadouts, each a different way to play the whole run - picking one
# writes the Global dice amounts directly (state first, flourish after), then the
# ceremony plays and Events.dice_loadout_completed hands control back to run.gd.
#
# Styling deliberately mirrors dice_infusion.gd (the act-transition ceremony): same
# fonts, same panel language, same halo/mote recipe - this is the same kind of beat,
# at the other end of the run. Sets are Julien's (2026-08-13); "The Disciple" is the
# classic 2 Blue + 1 Red start every run used before this screen existed.

const FONT_TITLE := preload("res://fonts/MinionPro-Bold.otf")
const FONT_SUBTITLE := preload("res://fonts/MinionPro-Semibold.otf")
const FONT_SET_NAME := preload("res://fonts/Cinzel-Bold.otf")
const FONT_CHUNKY := preload("res://fonts/LuckiestGuy-Regular.ttf")
const FONT_BODY := preload("res://fonts/NotoSans-Regular.ttf")
const CONFIRM_SOUND := preload("res://chargedicesound.mp3")
const DICE_TOOLTIP_SCENE := preload("res://scenes/ui/dice_tooltip.tscn")

const GOLD := Color(0.788235, 0.635294, 0.152941)  # the universal card-border gold
const TITLE_GOLD := Color(0.972439, 0.866667, 0.541176)  # act-banner gold
const CREAM := Color(0.93, 0.88, 0.8)
const PANEL_BG := Color(0.075, 0.055, 0.11)

const PANEL_MIN_SIZE := Vector2(228, 372)
# Die size scales down as a set shows more distinct types, so every dice row carries
# similar visual weight inside the same panel width. Sized so the widest row (3 types:
# 3 x (die + 8px cell padding) + 2 x 4px separation) stays inside the panel's ~200px
# interior - the harness asserts this.
const DIE_SIZES := {1: 106.0, 2: 82.0, 3: 54.0}
const MOTE_INTERVAL := 0.42  # per panel (one timer each, cycling that panel's dice)

# The representative face shown for each type (its best/most iconic face - same idea as
# DiceInfusions.preview_face; green is a d3, odd/even top out at 7/8, giant at 12).
const DISPLAY_FACES := {
    "blue": 6, "red": 6, "evil": 6, "giant": 12, "magma": 6,
    "even": 8, "odd": 7, "green": 3, "mech": 6,
}

# The five wishes. "dice" insertion order is the display order; the FIRST type is the
# set's signature (drives the selection accent). Counts are the full loadout - applying
# a set overwrites ALL nine types, zeroing whatever isn't listed (yes, Blue and Red
# included: Julien's sets deliberately drop them for some wishes).
const LOADOUTS: Array[Dictionary] = [
    {
        "id": "disciple",
        "title": "The Disciple",
        "dice": {"blue": 2, "red": 1},
    },
    {
        "id": "acrobat",
        "title": "The Acrobat",
        "dice": {"odd": 2, "red": 1},
    },
    {
        "id": "elf",
        "title": "The Elf",
        "dice": {"green": 4},
    },
    {
        "id": "titan",
        "title": "The Titan",
        "dice": {"giant": 1, "even": 1, "blue": 1},
    },
    {
        "id": "architect",
        "title": "The Architect",
        "dice": {"magma": 1, "blue": 1, "mech": 1},
    },
]

@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var options_box: HBoxContainer = $Options
@onready var confirm_button: Button = $ConfirmButton

var _selected_id := ""
var _hovered_id := ""
var _confirmed := false
var _panels := {}  # set id -> PanelContainer
var _cells := {}  # set id -> Array[Dictionary] {type, holder, glow, die}
var _accents := {}  # set id -> Color (signature dice accent)
# Halo breathing runs in _process with golden-ratio phase spacing (NOT looping tweens:
# a tween loop always starts at a leg boundary, which is exactly what made the dice
# shop's halos read as lockstep - same lesson, same fix).
var _breathers: Array[Dictionary] = []
var _elapsed := 0.0
var _die_tooltip: Node = null


func _ready() -> void:
    _style_chrome()
    _add_backdrop_glow()
    confirm_button.pressed.connect(_on_confirm_pressed)
    for loadout in LOADOUTS:
        options_box.add_child(_build_option_panel(loadout))
    _play_entrance()


func _process(delta: float) -> void:
    if _confirmed:
        return  # the ceremony owns the chosen glows; the rest are fading out anyway
    _elapsed += delta
    for entry: Dictionary in _breathers:
        var glow: TextureRect = entry["glow"]
        var wave: float = 0.5 + 0.5 * sin(TAU * _elapsed / entry["period"] + entry["phase"])
        glow.modulate.a = entry["base"] + entry["amp"] * wave
        var s: float = 1.0 + 0.05 * wave
        glow.scale = Vector2(s, s)


func _exit_tree() -> void:
    _cleanup_die_tooltip()


func _style_chrome() -> void:
    var title_settings := LabelSettings.new()
    title_settings.font = FONT_TITLE
    title_settings.font_size = 52
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

    confirm_button.add_theme_font_override("font", FONT_TITLE)
    confirm_button.add_theme_font_size_override("font_size", 24)
    confirm_button.add_theme_color_override("font_color", TITLE_GOLD)
    confirm_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
    confirm_button.add_theme_color_override("font_pressed_color", TITLE_GOLD)
    confirm_button.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.45))
    confirm_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.086, 0.157, 0.165), GOLD))
    confirm_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.12, 0.21, 0.22), GOLD.lightened(0.3)))
    confirm_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.06, 0.11, 0.12), GOLD))
    confirm_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.07, 0.09, 0.1), Color(0.35, 0.33, 0.28)))


# A huge, very faint warm radial behind everything - just enough depth that the black
# doesn't read as a void. Additive, so it can only ever add light.
func _add_backdrop_glow() -> void:
    var backdrop := TextureRect.new()
    backdrop.name = "BackdropGlow"
    backdrop.texture = DicePalette.glow_texture()
    backdrop.material = DicePalette.additive_material()
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_SCALE
    backdrop.size = Vector2(1500, 1050)
    backdrop.position = Vector2(640, 390) - backdrop.size / 2.0
    backdrop.modulate = Color(0.85, 0.7, 0.35, 0.07)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    move_child(backdrop, 1)  # above the Background fill, below everything else


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


func _build_option_panel(loadout: Dictionary) -> PanelContainer:
    var set_id: String = loadout["id"]
    var dice: Dictionary = loadout["dice"]
    var signature: String = dice.keys()[0]
    var accent := DicePalette.accent(signature)
    _accents[set_id] = accent
    _cells[set_id] = []

    var panel := PanelContainer.new()
    panel.name = set_id.capitalize() + "Option"
    panel.custom_minimum_size = PANEL_MIN_SIZE
    panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _make_panel_style(GOLD, false))
    panel.gui_input.connect(_on_panel_gui_input.bind(set_id))
    panel.mouse_entered.connect(_on_panel_hover.bind(set_id, true))
    panel.mouse_exited.connect(_on_panel_hover.bind(set_id, false))

    var margin := MarginContainer.new()
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 18)
    panel.add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_theme_constant_override("separation", 6)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    margin.add_child(vbox)

    var name_label := Label.new()
    name_label.text = String(loadout["title"]).to_upper()
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var name_settings := LabelSettings.new()
    name_settings.font = FONT_SET_NAME
    name_settings.font_size = 19
    name_settings.font_color = accent
    name_settings.outline_size = 5
    name_settings.outline_color = Color(0, 0, 0, 0.85)
    name_settings.shadow_size = 4
    name_settings.shadow_color = Color(0, 0, 0, 0.6)
    name_settings.shadow_offset = Vector2(2, 2)
    name_label.label_settings = name_settings
    vbox.add_child(name_label)

    # The dice themselves: one cell per distinct type, sized down as types multiply.
    var die_px: float = DIE_SIZES.get(dice.size(), 60.0)
    var dice_center := CenterContainer.new()
    dice_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(dice_center)
    var dice_row := HBoxContainer.new()
    dice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dice_row.add_theme_constant_override("separation", 4)
    dice_center.add_child(dice_row)
    # No text under the dice (Julien's call - the captions felt like clutter): the die
    # art + xN badges carry the set, and the per-die hover tooltips are now the ONLY
    # place type names are taught. Don't remove those without replacing that job.
    for type: String in dice:
        dice_row.add_child(_build_die_cell(set_id, type, int(dice[type]), die_px))

    # Rising accent motes, one shared timer per panel cycling its dice - "the wishes
    # are alive". Signature accent when idle; each mote picks its own die's color.
    var mote_timer := Timer.new()
    mote_timer.wait_time = MOTE_INTERVAL
    mote_timer.autostart = true
    mote_timer.timeout.connect(_spawn_panel_mote.bind(set_id))
    panel.add_child(mote_timer)

    _panels[set_id] = panel
    return panel


func _build_die_cell(set_id: String, dice_type: String, count: int, die_px: float) -> Control:
    var accent := DicePalette.accent(dice_type)

    var cell := VBoxContainer.new()
    cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cell.add_theme_constant_override("separation", 0)

    var holder := Control.new()
    holder.custom_minimum_size = Vector2(die_px + 8.0, die_px + 12.0)
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cell.add_child(holder)

    var glow := TextureRect.new()
    # Shaped halo (rounded square, follows the die silhouette) - the radial circle
    # behind a square die was rejected as shape-blind on the shop/infusion screens.
    # Kept <= die_px / 0.52 so the halo's hard core never peeks past the die art.
    glow.texture = DicePalette.die_halo_texture()
    glow.material = DicePalette.additive_material()
    glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.size = Vector2(die_px, die_px) * 1.72
    glow.position = (holder.custom_minimum_size - glow.size) / 2.0
    glow.pivot_offset = glow.size / 2.0
    glow.modulate = Color(accent.r, accent.g, accent.b, 0.3)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(glow)

    var die := TextureRect.new()
    die.texture = load("res://assets/images/%s%d.png" % [dice_type, DISPLAY_FACES[dice_type]])
    die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    die.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    die.size = Vector2(die_px, die_px)
    die.position = (holder.custom_minimum_size - die.size) / 2.0
    die.pivot_offset = die.size / 2.0
    # PASS: the die takes the hover (its type tooltip) but clicks still select the
    # panel - and gui_input is wired on the die too, so clicking the most clickable
    # thing on screen (the die art itself) always counts as picking the wish.
    die.mouse_filter = Control.MOUSE_FILTER_PASS
    die.mouse_entered.connect(_on_die_hover.bind(dice_type, die, true))
    die.mouse_exited.connect(_on_die_hover.bind(dice_type, die, false))
    die.gui_input.connect(_on_panel_gui_input.bind(set_id))
    holder.add_child(die)

    var count_label := Label.new()
    count_label.text = ("x%d" % count) if count > 1 else " "
    count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var count_settings := LabelSettings.new()
    count_settings.font = FONT_CHUNKY
    count_settings.font_size = 16
    count_settings.font_color = accent
    count_settings.outline_size = 4
    count_settings.outline_color = Color(0, 0, 0, 0.8)
    count_label.label_settings = count_settings
    cell.add_child(count_label)

    # Golden-ratio phase spacing by global die index: any group of visible halos lands
    # on well-separated points of the breathing cycle from frame one.
    _breathers.append({
        "glow": glow,
        "base": 0.24,
        "amp": 0.16,
        "period": randf_range(2.7, 3.4),
        "phase": fmod(_breathers.size() * 0.618, 1.0) * TAU,
    })
    (_cells[set_id] as Array).append({"type": dice_type, "holder": holder, "glow": glow, "die": die})
    return cell


func _play_entrance() -> void:
    title_label.modulate.a = 0.0
    subtitle_label.modulate.a = 0.0
    confirm_button.modulate.a = 0.0
    for id: String in _panels:
        (_panels[id] as Control).modulate.a = 0.0

    # Wait one frame so containers have laid out and sizes/pivots are real.
    await get_tree().process_frame
    title_label.pivot_offset = title_label.size / 2.0
    title_label.scale = Vector2(1.3, 1.3)
    for id: String in _panels:
        var panel: Control = _panels[id]
        panel.pivot_offset = panel.size / 2.0

    var intro := create_tween()
    intro.tween_property(title_label, "modulate:a", 1.0, 0.25)
    intro.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    intro.tween_property(subtitle_label, "modulate:a", 1.0, 0.3)

    # Panels stagger on their own overlapping tweens - in a single sequential tween each
    # fade BLOCKS the next, and five panels took ~2s to all appear (seen on the harness
    # still: the Architect was still invisible when the player could already click).
    var delay := 0.5
    for loadout in LOADOUTS:
        var id: String = loadout["id"]
        var panel_in := create_tween()
        panel_in.tween_interval(delay)
        panel_in.tween_property(_panels[id], "modulate:a", 1.0, 0.28)
        panel_in.parallel().tween_callback(_pop_dies.bind(id))
        delay += 0.12
    var button_in := create_tween()
    button_in.tween_interval(delay + 0.22)
    button_in.tween_property(confirm_button, "modulate:a", 1.0, 0.25)


func _pop_dies(set_id: String) -> void:
    var cells: Array = _cells[set_id]
    for i in cells.size():
        var die: TextureRect = cells[i]["die"]
        die.scale = Vector2(0.55, 0.55)
        die.modulate = Color(1.9, 1.9, 1.9)
        var pop := create_tween()
        if i > 0:
            pop.tween_interval(0.06 * i)
        pop.tween_property(die, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        pop.parallel().tween_property(die, "modulate", Color.WHITE, 0.32)


func _spawn_panel_mote(set_id: String) -> void:
    if _confirmed and set_id != _selected_id:
        return
    var cells: Array = _cells[set_id]
    var cell: Dictionary = cells[randi() % cells.size()]
    var holder: Control = cell["holder"]
    var accent := DicePalette.accent(cell["type"])

    var mote := TextureRect.new()
    mote.texture = DicePalette.glow_texture()
    mote.material = DicePalette.additive_material()
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_SCALE
    var mote_size := randf_range(7.0, 15.0)
    mote.size = Vector2(mote_size, mote_size)
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.modulate = Color(accent.r, accent.g, accent.b, 0.0)
    mote.position = Vector2(
        randf_range(4.0, holder.size.x - 4.0 - mote_size),
        holder.size.y - randf_range(0.0, 24.0)
    )
    holder.add_child(mote)

    var rise := randf_range(42.0, 76.0)
    var duration := randf_range(1.0, 1.5)
    var peak_alpha := randf_range(0.4, 0.65)
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(mote, "position:y", mote.position.y - rise, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.tween_property(mote, "position:x", mote.position.x + randf_range(-12.0, 12.0), duration)
    t.tween_property(mote, "modulate:a", peak_alpha, duration * 0.3)
    t.tween_property(mote, "modulate:a", 0.0, duration * 0.45).set_delay(duration * 0.55)
    t.chain().tween_callback(mote.queue_free)


func _on_die_hover(dice_type: String, die: Control, entered: bool) -> void:
    if _confirmed:
        return
    if entered:
        _show_die_tooltip(dice_type, die)
    else:
        _cleanup_die_tooltip()


func _show_die_tooltip(dice_type: String, die: Control) -> void:
    _cleanup_die_tooltip()
    _die_tooltip = DICE_TOOLTIP_SCENE.instantiate()
    Global.add_tooltip(_die_tooltip, self)
    var tooltip_panel: Panel = _die_tooltip.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content(dice_type)
    var rect := die.get_global_rect()
    var pos := Vector2(rect.position.x + rect.size.x * 0.5 - 102.0, rect.end.y + 12.0)
    pos.x = clampf(pos.x, 8.0, 1280.0 - 212.0)
    tooltip_panel.show_tooltip(pos)


func _cleanup_die_tooltip() -> void:
    if _die_tooltip and is_instance_valid(_die_tooltip):
        _die_tooltip.queue_free()
    _die_tooltip = null


func _on_panel_gui_input(event: InputEvent, set_id: String) -> void:
    if _confirmed:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _select(set_id)


func _on_panel_hover(set_id: String, entered: bool) -> void:
    if _confirmed:
        return
    _hovered_id = set_id if entered else ""
    _refresh_panel_visuals()


func _select(set_id: String) -> void:
    if _selected_id == set_id or _confirmed:
        return
    _selected_id = set_id
    SFXPlayer.play(Global.sfx_click)
    _refresh_panel_visuals()

    var panel: Control = _panels[set_id]
    var punch := create_tween()
    punch.tween_property(panel, "scale", Vector2(1.045, 1.045), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    punch.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    confirm_button.disabled = false


func _refresh_panel_visuals() -> void:
    for id: String in _panels:
        var panel: PanelContainer = _panels[id]
        if id == _selected_id:
            panel.add_theme_stylebox_override("panel", _make_panel_style(_accents[id], true))
            panel.modulate = Color.WHITE
        elif id == _hovered_id:
            panel.add_theme_stylebox_override("panel", _make_panel_style(GOLD.lightened(0.25), true))
            panel.modulate = Color.WHITE
        else:
            panel.add_theme_stylebox_override("panel", _make_panel_style(GOLD, false))
            panel.modulate = Color.WHITE if _selected_id == "" else Color(0.62, 0.62, 0.62)


func _loadout_by_id(set_id: String) -> Dictionary:
    for loadout in LOADOUTS:
        if loadout["id"] == set_id:
            return loadout
    return {}


# Writes the wish into the run. Overwrites ALL nine types - anything not in the set is
# zeroed (current too, so no phantom dice linger anywhere before the first battle's
# refill). The saved run picks this up for free: run.gd's checkpoint already serializes
# every type's max_amount.
func _apply_loadout(loadout: Dictionary) -> void:
    var dice: Dictionary = loadout["dice"]
    # Rebuilt, not appended to: reset_run_state seeds it with ["blue", "red"] (the classic
    # start), so a wish that drops either of them would otherwise leave the run claiming to
    # own dice it doesn't. The list is saved with the run and read by the card shop's deal
    # die, so a stale entry outlives this screen.
    var inventory: Array = []
    for type: String in Global.DICE_TYPE_ORDER:
        var count := int(dice.get(type, 0))
        Global.set(type + "_dice_max_amount", count)
        Global.set(type + "_dice_current_amount", count)
        if count > 0:
            inventory.append(type)
    Global.dice_inventory = inventory
    # Open on the wish's lead die rather than a Blue the player may not even own
    # (battle.gd re-derives this per fight via the same helper).
    Global.dice_type = Global.default_active_dice_type()
    Events.update_dice_top_bar.emit()


func _on_confirm_pressed() -> void:
    if _confirmed or _selected_id == "":
        return
    _confirmed = true
    confirm_button.disabled = true
    confirm_button.visible = false
    _cleanup_die_tooltip()

    # Lock the wish in immediately - state first, flourish after (same principle as the
    # infusion screen and the Power number updating before its orbs land).
    _apply_loadout(_loadout_by_id(_selected_id))

    SFXPlayer.play(CONFIRM_SOUND)

    # The unpicked wishes bow out. Alpha only - positions belong to the HBox.
    for id: String in _panels:
        if id == _selected_id:
            continue
        var fade := create_tween()
        fade.tween_property(_panels[id], "modulate:a", 0.0, 0.35)

    # Gather -> detonate -> settle, across every die of the chosen set at once.
    var cells: Array = _cells[_selected_id]
    var ceremony := create_tween()
    var anchor := true
    for c: Dictionary in cells:
        _ceremony_step(ceremony, anchor, c["glow"], "scale", Vector2(0.62, 0.62), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        anchor = false
        ceremony.parallel().tween_property(c["glow"], "modulate:a", 0.22, 0.22)
        ceremony.parallel().tween_property(c["die"], "scale", Vector2(0.88, 0.88), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    ceremony.tween_callback(_ceremony_detonate)
    anchor = true
    for c: Dictionary in cells:
        _ceremony_step(ceremony, anchor, c["glow"], "scale", Vector2(2.2, 2.2), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        anchor = false
        ceremony.parallel().tween_property(c["glow"], "modulate:a", 0.9, 0.1)
        ceremony.parallel().tween_property(c["die"], "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        ceremony.parallel().tween_property(c["die"], "modulate", Color(2.0, 2.0, 2.0), 0.12)
    anchor = true
    for c: Dictionary in cells:
        _ceremony_step(ceremony, anchor, c["die"], "modulate", Color.WHITE, 0.35)
        anchor = false
        ceremony.parallel().tween_property(c["die"], "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        ceremony.parallel().tween_property(c["glow"], "modulate:a", 0.55, 0.4)
        ceremony.parallel().tween_property(c["glow"], "scale", Vector2(1.25, 1.25), 0.4)
    ceremony.tween_interval(0.6)
    ceremony.tween_callback(func() -> void: Events.dice_loadout_completed.emit())


# First call of a step is the sequential anchor; everything else in the same beat rides
# parallel to it.
func _ceremony_step(tween: Tween, sequential_anchor: bool, object: Object, prop: String, value: Variant, dur: float) -> PropertyTweener:
    if sequential_anchor:
        return tween.tween_property(object, prop, value, dur)
    return tween.parallel().tween_property(object, prop, value, dur)


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
