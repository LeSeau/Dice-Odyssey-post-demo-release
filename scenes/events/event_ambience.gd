# A little life in the event picture (E3, H-189): slow glowing specks (mist, glints, embers,
# ash, motes, orbiting sparks) drawn over the picture. Only the specks move; the picture itself
# stays pinned (the menu's background drift was refused on 2026-08-30, its dust was kept).
#
# Same technique as main_menu.gd's ambient motes (DicePalette.glow_texture(), additive), but
# drawn with _draw() instead of one node per speck. Speck positions are in the picture's own
# pixels, and each speck fades with the picture's soft edge (feather_px, set by event_look.gd),
# so nothing hangs over the blurred backdrop. Pauses with the tree like everything else.
#
# Deliberately NO class_name: event_look.gd preload()s it (no global class cache step).
extends Control

# Emitter defaults per preset. Sizes are the glow radius in px on a 700x470 picture.
const PRESETS := {
    "mist": {"count": 12, "size": Vector2(40, 95), "alpha": Vector2(0.05, 0.11),
            "vx": Vector2(-4, 4), "vy": Vector2(-12, -5), "life": Vector2(5, 9),
            "color": Color(0.84, 0.97, 1.0), "add": true},
    "glints": {"count": 30, "size": Vector2(3.4, 7.7), "alpha": Vector2(0.55, 1.0),
            "vx": Vector2(0, 0), "vy": Vector2(0, 0), "life": Vector2(0.5, 1.4),
            "color": Color(0.8, 1.0, 0.98), "add": true, "flare": true, "twinkle": true},
    "embers": {"count": 34, "size": Vector2(3.1, 7.2), "alpha": Vector2(0.6, 1.0),
            "vx": Vector2(-8, 8), "vy": Vector2(-42, -18), "life": Vector2(2, 4),
            "color": Color(1.0, 0.41, 0.23), "add": true, "sway": 16.0},
    "ash": {"count": 14, "size": Vector2(2.4, 5.0), "alpha": Vector2(0.25, 0.5),
            "vx": Vector2(-6, 6), "vy": Vector2(6, 15), "life": Vector2(5, 9),
            "color": Color(0.65, 0.59, 0.59), "add": false, "sway": 10.0},
    "motes": {"count": 42, "size": Vector2(2.9, 7.0), "alpha": Vector2(0.35, 0.95),
            "vx": Vector2(-4, 4), "vy": Vector2(-10, -3), "life": Vector2(4, 8),
            "color": Color(1.0, 0.84, 0.47), "add": true, "sway": 6.0, "shimmer": true},
    "orbit": {"count": 36, "size": Vector2(3.1, 7.2), "alpha": Vector2(0.5, 1.0),
            "life": Vector2(3, 6), "speed": Vector2(0.35, 0.9), "radius": Vector2(0.1, 0.34),
            "center": Vector2(0.6, 0.55), "color": Color(0.77, 0.47, 1.0),
            "color2": Color(1.0, 0.78, 0.35), "add": true},
}

# Set by event_look.gd before add_child: [{preset, area: Rect2 (0..1 of the picture), color?,
# count?, center?}], plus the picture's soft-edge widths (left, top, right, bottom).
var emitters: Array = []
var feather_px := Vector4(34, 34, 90, 34)

var _add_layer: _Layer
var _normal_layer: _Layer
var _specks: Array = []
var _time := 0.0


class _Layer extends Control:
    # Untyped on purpose: draw_specks() lives on the outer script, not on Control.
    var owner_ambience
    var additive := true

    func _draw() -> void:
        owner_ambience.draw_specks(self, additive)


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _normal_layer = _make_layer(false)
    _add_layer = _make_layer(true)
    for e: Dictionary in emitters:
        var preset: Dictionary = PRESETS.get(e.get("preset", ""), {})
        if preset.is_empty():
            continue
        var count: int = e.get("count", preset["count"])
        for i in count:
            var s := _spawn(e, preset)
            s["age"] = randf() * s["life"]  # start mid-flight, never an empty picture
            _specks.append(s)


func _make_layer(additive: bool) -> _Layer:
    var layer := _Layer.new()
    layer.owner_ambience = self
    layer.additive = additive
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if additive:
        layer.material = DicePalette.additive_material()
    add_child(layer)
    return layer


func _spawn(e: Dictionary, preset: Dictionary) -> Dictionary:
    var area: Rect2 = e.get("area", Rect2(0, 0, 1, 1))
    var s := {
        "e": e, "p": preset,
        "age": 0.0,
        "life": randf_range(preset["life"].x, preset["life"].y),
        "size": randf_range(preset["size"].x, preset["size"].y),
        "alpha": randf_range(preset["alpha"].x, preset["alpha"].y),
        "phase": randf() * TAU,
        "color": e.get("color", preset["color"]),
    }
    if e.get("preset") == "orbit":
        s["angle"] = randf() * TAU
        s["radius"] = randf_range(preset["radius"].x, preset["radius"].y)
        var dir := -1.0 if randf() < 0.5 else 1.0
        s["speed"] = randf_range(preset["speed"].x, preset["speed"].y) * dir
        if randf() < 0.5:
            s["color"] = e.get("color2", preset["color2"])
    else:
        s["u"] = randf_range(area.position.x, area.end.x)
        s["v"] = randf_range(area.position.y, area.end.y)
        s["vx"] = randf_range(preset["vx"].x, preset["vx"].y)
        s["vy"] = randf_range(preset["vy"].x, preset["vy"].y)
    return s


func _process(delta: float) -> void:
    _time += delta
    for i in _specks.size():
        var s: Dictionary = _specks[i]
        s["age"] += delta
        if s["age"] >= s["life"]:
            _specks[i] = _spawn(s["e"], s["p"])
        elif s.has("angle"):
            s["angle"] += s["speed"] * delta
    _add_layer.queue_redraw()
    _normal_layer.queue_redraw()


func _speck_position(s: Dictionary) -> Vector2:
    var w := size.x
    var h := size.y
    if s.has("angle"):
        var c: Vector2 = s["e"].get("center", s["p"]["center"])
        return Vector2((c.x + cos(s["angle"]) * s["radius"]) * w,
                (c.y + sin(s["angle"]) * s["radius"] * 0.72) * h)
    var sway: float = s["p"].get("sway", 0.0)
    var x: float = s["u"] * w + s["vx"] * s["age"] + sin(s["age"] * 1.6 + s["phase"]) * sway
    var y: float = s["v"] * h + s["vy"] * s["age"]
    return Vector2(x, y)


# 0 at the picture's edge, 1 once past its soft edge: specks fade exactly like the picture.
func _edge_fade(p: Vector2) -> float:
    return smoothstep(0.0, maxf(feather_px.x, 1.0), p.x) \
            * smoothstep(0.0, maxf(feather_px.z, 1.0), size.x - p.x) \
            * smoothstep(0.0, maxf(feather_px.y, 1.0), p.y) \
            * smoothstep(0.0, maxf(feather_px.w, 1.0), size.y - p.y)


func draw_specks(layer: Control, additive: bool) -> void:
    var tex := DicePalette.glow_texture()
    for s: Dictionary in _specks:
        var preset: Dictionary = s["p"]
        if bool(preset["add"]) != additive:
            continue
        var t: float = s["age"] / s["life"]
        var fade := minf(1.0, t * 4.0) * minf(1.0, (1.0 - t) * 3.0)
        var a: float = s["alpha"] * fade
        if preset.get("twinkle", false):
            a *= 0.5 + 0.5 * sin(t * PI)
        if preset.get("shimmer", false):
            a *= 0.65 + 0.35 * sin(s["age"] * 3.0 + s["phase"])
        var p := _speck_position(s)
        a *= _edge_fade(p)
        if a <= 0.01:
            continue
        var r: float = s["size"]
        var col: Color = s["color"]
        layer.draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false,
                Color(col.r, col.g, col.b, a))
        if preset.get("flare", false) and a > 0.4:
            # Four-point glint: two thin stretched glows crossing.
            var fa := (a - 0.4) * 0.9
            var arm := r * 2.8
            var thin := maxf(1.2, r * 0.28)
            layer.draw_texture_rect(tex, Rect2(p - Vector2(arm, thin), Vector2(arm, thin) * 2.0),
                    false, Color(1, 1, 1, fa))
            layer.draw_texture_rect(tex, Rect2(p - Vector2(thin, arm), Vector2(thin, arm) * 2.0),
                    false, Color(1, 1, 1, fa))
