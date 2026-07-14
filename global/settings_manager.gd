class_name SettingsManager
extends RefCounted

# Persistent player settings (audio volumes + fullscreen), stored in user:// next to
# the run save. All static, mirroring SaveManager - call load_and_apply() once at
# startup (done in Global._ready()), then the pause menu reads/writes via
# get_value()/set_value(), which apply live and save immediately.
#
# Volumes are stored linear 0..1 and applied as attenuation ON TOP of the bus dB
# authored in default_bus_layout.tres (Music sits at ~-7.6 dB there as part of the
# game's mix). Writing the slider dB straight into the bus would silently destroy
# that authored mix the first time the player touched a slider - so the authored
# values are captured once at startup as baselines instead.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"

const DEFAULTS := {
    "master_volume": 1.0,
    "music_volume": 1.0,
    "sfx_volume": 1.0,
    "fullscreen": false,
}

static var _values := {}
static var _baseline_db := {}
static var _loaded := false


static func load_and_apply() -> void:
    _ensure_loaded()
    _apply_all()


static func get_value(key: String) -> Variant:
    _ensure_loaded()
    return _values.get(key, DEFAULTS.get(key))


static func set_value(key: String, value: Variant) -> void:
    _ensure_loaded()
    _values[key] = value
    _apply_all()
    _save()


static func _ensure_loaded() -> void:
    if _loaded:
        return
    _loaded = true
    _values = DEFAULTS.duplicate()
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        for key: String in DEFAULTS.keys():
            _values[key] = cfg.get_value(SECTION, key, DEFAULTS[key])
    # Capture the authored mix BEFORE anything is applied - as long as this first
    # runs at startup (Global._ready), these are the default_bus_layout.tres values.
    for bus_name: String in ["Master", "Music", "SFX"]:
        var idx := AudioServer.get_bus_index(bus_name)
        if idx >= 0:
            _baseline_db[bus_name] = AudioServer.get_bus_volume_db(idx)


static func _save() -> void:
    var cfg := ConfigFile.new()
    for key: String in _values.keys():
        cfg.set_value(SECTION, key, _values[key])
    cfg.save(SETTINGS_PATH)


static func _apply_all() -> void:
    _apply_bus("Master", _values["master_volume"])
    _apply_bus("Music", _values["music_volume"])
    _apply_bus("SFX", _values["sfx_volume"])
    _apply_fullscreen(_values["fullscreen"])


static func _apply_bus(bus_name: String, linear: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx < 0:
        return
    var muted: bool = linear <= 0.005
    AudioServer.set_bus_mute(idx, muted)
    if not muted:
        var base: float = _baseline_db.get(bus_name, 0.0)
        AudioServer.set_bus_volume_db(idx, base + linear_to_db(linear))


static func _apply_fullscreen(on: bool) -> void:
    # _apply_all() (and therefore this) reruns on EVERY settings write, including every single
    # value_changed tick while dragging a volume slider - not just when the fullscreen toggle
    # itself is touched. The old unconditional "else -> force WINDOWED" branch treated a
    # manually-Maximized window as "wrong" and stomped it back to WINDOWED on every slider
    # tick, which read as the window minimizing/shrinking the moment you touched a volume
    # slider. Only ever actively CHANGE the window mode in the direction the setting asks for:
    # turn fullscreen on if it isn't already, or leave fullscreen if it's currently on - never
    # touch any other window state (Windowed, Maximized) that the player set themselves.
    var current := DisplayServer.window_get_mode()
    if on:
        if current != DisplayServer.WINDOW_MODE_FULLSCREEN:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    elif current == DisplayServer.WINDOW_MODE_FULLSCREEN:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
