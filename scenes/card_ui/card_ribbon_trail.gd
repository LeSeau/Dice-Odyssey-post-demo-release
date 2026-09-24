extends Line2D

# Ribbon trail behind a flying card (2026-09-24), after STS2's NCardTrail: a point every
# 12-48px along the path, each point lives POINT_LIFE seconds, and the tail thins out and fades,
# so the streak shows where the card has just been. It replaces the two dense mote layers the
# played card used to shed (a wake over the whole flight plus a 20ms comet on the exit), which
# read as fizz rather than as one motion.
#
# Lives on the ui_layer, NOT on the card. The card shrinks, turns and is freed on arrival, and a
# child would be scaled, turned and freed with it. It follows its node through a WeakRef and
# frees itself once its last point has expired, so nobody has to clean it up.
#
# No class_name on purpose: card_send_off.gd preloads it, and a class_name would put it in the
# global cache the editor has to rescan before any harness can see it.

const POINT_LIFE := 0.8
const MIN_SPACING := 12.0
const MAX_SPACING := 48.0
# Failsafe against a follow target that never goes away.
const MAX_LIFETIME := 8.0

var _follow_ref: WeakRef = null
var _ages: PackedFloat32Array = PackedFloat32Array()
var _last := Vector2.INF
var _emitting := true
var _life := 0.0


# `color` must keep every channel at or below 1: the ribbon is additive, and a channel above 1
# clamps on its own, so a hue with two strong channels would drift to white. Brightness rides on
# alpha instead.
func setup(follow: Control, color: Color, head_width: float) -> void:
    _follow_ref = weakref(follow)
    width = head_width
    joint_mode = Line2D.LINE_JOINT_ROUND
    begin_cap_mode = Line2D.LINE_CAP_ROUND
    end_cap_mode = Line2D.LINE_CAP_ROUND
    antialiased = true
    # Width and colour both run from the oldest point (0, the tail) to the newest (1, the head).
    var curve := Curve.new()
    curve.add_point(Vector2(0.0, 0.0))
    curve.add_point(Vector2(0.55, 0.62))
    curve.add_point(Vector2(1.0, 1.0))
    width_curve = curve
    var hot := color.lerp(Color.WHITE, 0.45)
    var g := Gradient.new()
    g.set_color(0, Color(color.r, color.g, color.b, 0.0))
    g.set_color(1, Color(hot.r, hot.g, hot.b, 0.95))
    g.add_point(0.6, Color(color.r, color.g, color.b, 0.6))
    gradient = g
    material = DicePalette.additive_material()


# Stop adding points; what is already drawn fades out on its own and the node then frees itself.
func stop() -> void:
    _emitting = false


func _process(delta: float) -> void:
    _life += delta
    for i in _ages.size():
        _ages[i] += delta
    while _ages.size() > 0 and _ages[0] > POINT_LIFE:
        _ages.remove_at(0)
        remove_point(0)
    if _emitting:
        var follow: Control = null
        if _follow_ref != null:
            follow = _follow_ref.get_ref() as Control
        if follow == null or not follow.is_inside_tree() or not follow.is_visible_in_tree():
            _emitting = false
        else:
            _feed(follow.get_global_transform() * (follow.size * 0.5))
    if (not _emitting and _ages.is_empty()) or _life > MAX_LIFETIME:
        queue_free()


func _feed(p: Vector2) -> void:
    if _last == Vector2.INF:
        _add(p)
        return
    var d := p.distance_to(_last)
    if d < MIN_SPACING:
        return
    # A fast frame jumps further than MAX_SPACING: fill the gap so the ribbon stays a curve
    # rather than a few long straight segments.
    if d > MAX_SPACING:
        var from := _last
        var steps := int(floor(d / MAX_SPACING))
        for k in range(1, steps + 1):
            _add(from.lerp(p, float(k) / float(steps + 1)))
    _add(p)


func _add(p: Vector2) -> void:
    add_point(p)
    _ages.append(0.0)
    _last = p
