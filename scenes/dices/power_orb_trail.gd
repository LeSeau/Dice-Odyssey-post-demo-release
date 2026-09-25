extends Line2D

# Comet tail for the pip orbs (dice.gd _spawn_pip_orbs, 2026-09-25, H-184). Same idea as
# scenes/card_ui/card_ribbon_trail.gd (points sampled along the path, each with a short life,
# tapered and faded toward the tail), but short-lived and tight, because an orb flight is
# ~0.3s where a card flight is ~1s. Follows its orb through a WeakRef and frees itself once
# the orb is gone and its last point has expired.
# No class_name on purpose: dice.gd preloads it, so there is no global class cache to go
# stale in a headless run.

var point_life := 0.16
var min_spacing := 3.0
var max_spacing := 14.0

var _follow_ref: WeakRef = null
var _ages: PackedFloat32Array = PackedFloat32Array()
var _last := Vector2.INF
var _emitting := true
var _life := 0.0


# Colour channels must stay <= 1: additive blending clamps per channel, so brightness rides
# on alpha (documented clamp trap).
func setup(follow: Control, color: Color, head_width: float, life := 0.16) -> void:
    _follow_ref = weakref(follow)
    point_life = life
    width = head_width
    joint_mode = Line2D.LINE_JOINT_ROUND
    begin_cap_mode = Line2D.LINE_CAP_ROUND
    end_cap_mode = Line2D.LINE_CAP_ROUND
    antialiased = true
    var curve := Curve.new()
    curve.add_point(Vector2(0.0, 0.0))
    curve.add_point(Vector2(0.6, 0.55))
    curve.add_point(Vector2(1.0, 1.0))
    width_curve = curve
    var hot := color.lerp(Color.WHITE, 0.55)
    var g := Gradient.new()
    g.set_color(0, Color(color.r, color.g, color.b, 0.0))
    g.set_color(1, Color(hot.r, hot.g, hot.b, 0.95))
    g.add_point(0.55, Color(color.r, color.g, color.b, 0.55))
    gradient = g
    material = DicePalette.additive_material()


func stop() -> void:
    _emitting = false


func _process(delta: float) -> void:
    _life += delta
    for i in _ages.size():
        _ages[i] += delta
    while _ages.size() > 0 and _ages[0] > point_life:
        _ages.remove_at(0)
        remove_point(0)
    if _emitting:
        var follow: Control = null
        if _follow_ref != null:
            follow = _follow_ref.get_ref() as Control
        if follow == null or not follow.is_inside_tree():
            _emitting = false
        else:
            _feed(follow.get_global_transform() * (follow.size * 0.5))
    if (not _emitting and _ages.is_empty()) or _life > 4.0:
        queue_free()


func _feed(p: Vector2) -> void:
    # Line2D points are in this node's local space; the trail sits at the canvas origin of
    # its parent, so convert from global.
    var local := get_global_transform().affine_inverse() * p
    if _last == Vector2.INF:
        _add(local)
        return
    var d := local.distance_to(_last)
    if d < min_spacing:
        return
    if d > max_spacing:
        var from := _last
        var steps := int(floor(d / max_spacing))
        for k in range(1, steps + 1):
            _add(from.lerp(local, float(k) / float(steps + 1)))
    _add(local)


func _add(p: Vector2) -> void:
    add_point(p)
    _ages.append(0.0)
    _last = p
