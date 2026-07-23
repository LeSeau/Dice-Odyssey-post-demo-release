class_name Enemy
extends Area2D

const ARROW_OFFSET := 5
# NameLabel now lives in its own CanvasLayer (see update_enemy()/_on_mouse_entered()
# below) so it can render above the hand of cards - a CanvasLayer boundary always wins
# over z_index, so as a plain child of Enemy it could never draw over BattleUI's Hand
# no matter what z_index it had. Width/center match the box it used to occupy locally;
# kept as constants here since the label is now positioned by hand in screen space
# instead of via Control offsets under Enemy's own transform.
const NAME_LABEL_WIDTH := 206.0
const NAME_LABEL_SPRITE_CENTER_X := 124.0
const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")
const TARGET_HIGHLIGHT_OUTLINE_COLOR := Color(2.0, 1.7, 0.6, 1.0)
const TARGET_HIGHLIGHT_OUTLINE_THICKNESS := 3.0
const TARGET_HIGHLIGHT_FADE_IN_DURATION := 0.1

# Captured once at startup: the enemy's own outline ShaderMaterial. take_damage()'s
# hit-flash clears sprite_2d.material to null after the FIRST hit (see below), which
# would otherwise permanently lose this shader and silently break anything (like the
# target highlight) that depends on it existing.
var _base_sprite_material: ShaderMaterial
var _target_highlight_tween: Tween

# Hit-reaction state (knockback + squash). Rest values captured once per hit-burst so
# repeated hits in quick succession can't accumulate positional/scale drift.
var _hit_pos_tween: Tween
var _hit_squash_tween: Tween
var _hit_rest_position: Vector2
var _hit_rest_sprite_scale: Vector2
var _hit_reaction_active := false

@export var stats: EnemyStats : set = set_enemy_stats
@export var width: int 
@export var height: int
@export var initial_statuses: Array[Status] = []
@export var sprite_y_offset: int = 0
@onready var sprite_2d: Sprite2D = $SpriteRoot/Sprite2D
@export var stats_ui_y_offset: int = 0
@export var intent_ui_y_offset: int = 0
@onready var arrow: Sprite2D = $Arrow
@onready var stats_ui: StatsUI = $StatsUI
@onready var name_label_layer: CanvasLayer = $NameLabelLayer
@onready var name_label: Label = $NameLabelLayer/NameLabel
@onready var intent_ui: IntentUI = $IntentUI
@export var status_handler_y_offset: int = 0
@onready var status_handler: StatusHandler = $StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler
@onready var animation_player: AnimationPlayer = $AnimationPlayer


var enemy_action_picker: EnemyActionPicker
var current_action: EnemyAction : set = set_current_action

var last_action: String = ""
var last_action_count: int = 0
var blocked_last_turn: bool = false

# Captured at set_enemy_stats() time, BEFORE create_instance()'s duplicate() call - a
# duplicated Resource doesn't reliably keep the original's resource_path, so deriving the
# fallback name from the file later (once `stats` only holds the duplicate) wouldn't work.
var _display_name := ""

# Local (unscaled) Y of the name label's box, computed in update_enemy() alongside
# stats_ui - converted to a screen-space CanvasLayer offset on hover, see
# _on_mouse_entered().
var _name_label_local_y: float = 0.0
# Local X of the name label, same idea - defaults to the legacy flat guess and gets
# overridden in update_enemy() if stats.content_center_x was actually measured.
var _name_label_local_x: float = NAME_LABEL_SPRITE_CENTER_X


func _ready() -> void:
    _base_sprite_material = sprite_2d.material as ShaderMaterial

    # Idle already started via autoplay by the time this runs (children enter the tree
    # before their parent's _ready()) - nudge its phase/speed so multiple enemies on
    # screen at once don't all breathe in perfect lockstep (same "idle" animation, same
    # start time otherwise), which is exactly what read as robotic before this.
    animation_player.speed_scale = randf_range(0.85, 1.2)
    animation_player.seek(randf() * animation_player.current_animation_length, true)



func set_current_action(value: EnemyAction) -> void:
    current_action = value
    update_intent()


func set_enemy_stats(value: EnemyStats) -> void:
    _display_name = _compute_display_name(value)
    stats = value.create_instance()
    
    if not stats.stats_changed.is_connected(update_stats):
        stats.stats_changed.connect(update_stats)
        stats.stats_changed.connect(update_intent)
        Events.enemy_strength_changed.connect(update_intent)
        
    
    update_enemy()
    _apply_initial_statuses()  # <-- add this

func _apply_initial_statuses() -> void:
    if not is_inside_tree():
        await ready
    for status in initial_statuses:
        status_handler.add_status(status.duplicate())

func setup_ai() -> void:
    if enemy_action_picker:
        enemy_action_picker.queue_free()
        
    var new_action_picker := stats.ai.instantiate() as EnemyActionPicker
    add_child(new_action_picker)
    enemy_action_picker = new_action_picker
    enemy_action_picker.enemy = self


func update_stats() -> void:
    stats_ui.update_stats(stats)


func update_action() -> void:
    if not enemy_action_picker:
        return

    current_action = enemy_action_picker.get_action()


const MAX_ENEMY_WIDTH := 256.0
const MAX_ENEMY_HEIGHT := 256.0

# Keep the status-icon row clear of the End Turn button (BattleUI, bottom-right:
# x 1060..1254 in the 1280x720 design space). The row is an HBox that grows
# rightward from its start x, so the START is clamped to leave ~2-3 icons of slack
# before the button's left edge. Calibrated from real placements (probe_feet):
# Oculus starts at gx 1017 (the one that overlapped End Turn) and gets pulled in;
# Gargantua at 951 is comfortably clear and must NOT move (a 910 threshold wrongly
# yanked its status 41px left). Screen-space constant, not a live BattleUI lookup:
# the battle camera is identity (centered on the 1280x720 design rect) and enemy.gd
# has no clean handle into the BattleUI CanvasLayer. The Y guard keeps a
# hypothetical high-placed enemy's status from being nudged for no reason.
const STATUS_ROW_MAX_GLOBAL_X := 970.0
const STATUS_ROW_CLAMP_MIN_GLOBAL_Y := 500.0

# Alpha-bbox of each enemy texture's actual content, cached per texture path -
# feet-anchoring (below) needs it once per texture, and get_image() on an
# imported texture decompresses (cheap enough once, wasteful per battle).
static var _content_rect_cache := {}
# Shared soft radial gradient used by every enemy's ground shadow.
static var _shadow_texture: GradientTexture2D

var _ground_shadow: Sprite2D


static func _get_shadow_texture() -> GradientTexture2D:
    if _shadow_texture == null:
        var gradient := Gradient.new()
        gradient.colors = PackedColorArray([
            Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.32), Color(0, 0, 0, 0.0)
        ])
        gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
        _shadow_texture = GradientTexture2D.new()
        _shadow_texture.gradient = gradient
        _shadow_texture.width = 256
        _shadow_texture.height = 256
        _shadow_texture.fill = GradientTexture2D.FILL_RADIAL
        _shadow_texture.fill_from = Vector2(0.5, 0.5)
        _shadow_texture.fill_to = Vector2(0.5, 0.0)
    return _shadow_texture


static func _get_content_rect(tex: Texture2D) -> Rect2:
    var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
    if _content_rect_cache.has(key):
        return _content_rect_cache[key]
    var rect := Rect2(Vector2.ZERO, tex.get_size())
    var img := tex.get_image()
    if img != null:
        var used := img.get_used_rect()
        if used.size.x > 0 and used.size.y > 0:
            rect = Rect2(used)
    _content_rect_cache[key] = rect
    return rect


func update_enemy() -> void:
    if not stats is Stats:
        return
    if not is_inside_tree():
        await ready

    sprite_2d.texture = stats.art
    sprite_2d.modulate = Color(1, 1, 1, 1)

    var tex_size = sprite_2d.texture.get_size()

    # Fallback defaults if not set in inspector
    var target_width := width if width > 0 else 256
    var target_height := height if height > 0 else 256

    if tex_size.x > 0 and tex_size.y > 0:
        var width_scale = target_width / tex_size.x
        var height_scale = target_height / tex_size.y
        var final_scale = min(width_scale, height_scale)
        sprite_2d.scale = Vector2(final_scale, final_scale)

        var sprite_display_height = tex_size.y * final_scale

        # --- Feet-anchoring (2026-07-19, re-fixed 2026-07-20) --------------------
        # Put the art's CONTENT bottom (alpha bbox) on the BOX bottom - the ground line
        # the level designer tuned position.y against (they placed enemies assuming the
        # sprite fills its box). For a padding-free texture this is a no-op (content
        # bottom already = box bottom); for one with bottom padding it pushes the sprite
        # down so the *visible* feet reach the ground instead of floating above it.
        # feet_line_y is the single source of truth for "where the feet are" - the sprite,
        # the HP bar, the status row and the shadow all derive from it below.
        var content := _get_content_rect(sprite_2d.texture)
        var content_bottom_from_center: float = (content.end.y - tex_size.y / 2.0) * final_scale
        var feet_line_y: float = sprite_y_offset + sprite_display_height / 2.0
        sprite_2d.position.y = feet_line_y - content_bottom_from_center

        # --- HP bar / status / name hang from the VISIBLE FEET, never above them ------
        # THIS is the fix for the endless "sprite overlaps its own HP bar" saga. The bar
        # used to be computed from the box + per-fight stats_ui_y_offset, and a NEGATIVE
        # offset (Marauder -24, Vortex -10, Lurker+Crab -8) yanked it UP into the body.
        # Now the bar sits AT the feet line; the offsets survive only as DOWNWARD nudges
        # (maxf(.,0)) so the bar can never ride up into the sprite no matter what any
        # present-or-future per-fight tuning says. Enemies with a 0 offset are unchanged.
        stats_ui.position.y = feet_line_y + maxf(stats_ui_y_offset, 0.0)
        status_handler.position.y = stats_ui.position.y + stats_ui.size.y - 8.0 + maxf(status_handler_y_offset, 0.0)
        _name_label_local_y = stats_ui.position.y + stats_ui.size.y + 4

        # Intent floats above the head (box-based; unchanged - it clears the head fine and
        # its per-fight intent_ui_y_offset tuning is still honored).
        intent_ui.position.y = -sprite_display_height / 2 - 30 - intent_ui_y_offset + sprite_y_offset

        # sprite_2d.position.x is a fixed baseline baked into enemy.tscn's template (124,
        # never reassigned by code, same value NAME_LABEL_SPRITE_CENTER_X was hand-copied
        # from) - has to be added back in, not replaced, or the label loses that baseline
        # entirely and drifts hard left. Only the content-fraction term is enemy-specific.
        _name_label_local_x = sprite_2d.position.x
        if stats.content_center_x >= 0.0:
            _name_label_local_x += (stats.content_center_x - 0.5) * tex_size.x * final_scale

        # --- Ground shadow (2026-07-19) ------------------------------------------
        # Soft ellipse at the feet line, STS-style: sells grounding even for art drawn
        # in a mid-leap/diagonal pose (Lava Hound) that no offset can fix, and makes
        # deliberate floaters read as "hovering above their shadow" instead of just
        # misplaced. Child of the Enemy root, NOT SpriteRoot - the idle bob animates
        # SpriteRoot, and the shadow must stay put while the body bobs.
        if _ground_shadow == null:
            _ground_shadow = Sprite2D.new()
            _ground_shadow.texture = _get_shadow_texture()
            add_child(_ground_shadow)
            move_child(_ground_shadow, 0)  # draw behind SpriteRoot
        var content_center_x_local: float = sprite_2d.position.x \
            + (content.get_center().x - tex_size.x / 2.0) * final_scale
        var shadow_width: float = content.size.x * final_scale * 0.82
        # Just below the feet (feet at feet_line_y), so it peeks out around them.
        _ground_shadow.position = Vector2(content_center_x_local, feet_line_y + 5.0)
        _ground_shadow.scale = Vector2(shadow_width / 256.0, shadow_width * 0.24 / 256.0)
    else:
        sprite_2d.position.y = sprite_y_offset

    # Clamp the status row's start so its icons can't run into the End Turn button
    # (right-edge enemies: Oculus in tier_1_oculus_goblin had its status icons sitting on
    # the button). Only for statuses low enough to reach the button band.
    if scale.x != 0:
        var status_global_x: float = global_position.x + status_handler.position.x * scale.x
        var status_global_y: float = global_position.y + status_handler.position.y * scale.y
        if status_global_x > STATUS_ROW_MAX_GLOBAL_X and status_global_y > STATUS_ROW_CLAMP_MIN_GLOBAL_Y:
            status_handler.position.x = (STATUS_ROW_MAX_GLOBAL_X - global_position.x) / scale.x

    # Multi-enemy battle scenes set `scale` on the Enemy root to fit several bodies. The
    # StatusHandler inherits that shrink; counter-scale it so status icons stay a constant
    # size no matter the enemy's own scale.
    if scale.x != 0 and scale.y != 0:
        status_handler.scale = Vector2(1.0 / scale.x, 1.0 / scale.y)
    arrow.position = Vector2.RIGHT * (sprite_2d.get_rect().size.x * sprite_2d.scale.x / 2 + ARROW_OFFSET)
    setup_ai()
    update_stats()
    setup_ai()
    update_stats()

func update_intent() -> void:
    if current_action:
        current_action.update_intent_text()
        intent_ui.update_intent(current_action.intent)


func do_turn() -> void:
    stats.block = 0

    if not current_action:
        return

    current_action.perform_action()

    # Track last action
    if last_action == current_action.action_id:
        last_action_count += 1
    else:
        last_action = current_action.action_id
        last_action_count = 1


func take_damage(damage: int, which_modifier: Modifier.Type) -> void:
    if stats.health <= 0:
        return

    sprite_2d.material = WHITE_SPRITE_MATERIAL
    var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
    Global.damage_to_display = modified_damage

    _play_hit_reaction()
    stats.take_damage(modified_damage)

    # Short, sharp white flash. Was 0.17s, which left the enemy a featureless white
    # silhouette long enough to erase its art and mask the hit reaction underneath.
    # Decoupled from the death trigger below so the flash length is independent of it.
    var flash_tween := create_tween()
    flash_tween.tween_interval(0.06)
    flash_tween.tween_callback(
        func():
            if stats.health <= 0:
                # Drop the outline shader entirely rather than restoring it:
                # its fragment() ignores incoming modulate/alpha, so the
                # death-fade below would have no visible effect on this
                # sprite while it's assigned. The enemy is about to be
                # freed anyway, so it no longer needs highlight capability.
                sprite_2d.material = null
                Global.run_stat_enemies_slain += 1
                Events.enemy_died.emit(self)
                var death_tween := create_tween()
                death_tween.tween_property(self, "modulate:a", 0.0, 0.4)
                death_tween.tween_callback(queue_free)
            else:
                sprite_2d.material = _base_sprite_material
    )


# Directional knockback + sprite squash on hit. Knockback rides self.position (the same
# property Shaker.shake used safely - the idle animation owns SpriteRoot, not the root),
# squash rides Sprite2D.scale directly (idle owns SpriteRoot's transform, not the sprite's).
func _play_hit_reaction() -> void:
    if not _hit_reaction_active:
        _hit_rest_position = position
        _hit_rest_sprite_scale = sprite_2d.scale
        _hit_reaction_active = true

    if _hit_pos_tween and _hit_pos_tween.is_valid():
        _hit_pos_tween.kill()
    if _hit_squash_tween and _hit_squash_tween.is_valid():
        _hit_squash_tween.kill()

    # Enemies sit to the right of the player, so they recoil rightward (+x).
    _hit_pos_tween = create_tween()
    _hit_pos_tween.tween_property(self, "position", _hit_rest_position + Vector2(16, 0), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_pos_tween.tween_property(self, "position", _hit_rest_position, 0.3) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _hit_pos_tween.tween_callback(func(): _hit_reaction_active = false)

    _hit_squash_tween = create_tween()
    _hit_squash_tween.tween_property(sprite_2d, "scale", Vector2(_hit_rest_sprite_scale.x * 1.15, _hit_rest_sprite_scale.y * 0.85), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_squash_tween.tween_property(sprite_2d, "scale", _hit_rest_sprite_scale, 0.28) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_area_entered(_area: Area2D) -> void:
    arrow.hide()


func _on_area_exited(_area: Area2D) -> void:
    arrow.hide()


func _on_mouse_entered() -> void:
    name_label.text = _display_name
    # Center the label on the visible red HealthBar's actual on-screen center - that bar
    # is the anchor the player reads "centered" against, and it sidesteps per-art
    # content-centering guesswork entirely (a swapped act-2 sprite lines up as well as a
    # hand-tuned act-1 one). NOTE: StatsUI is an HBoxContainer, so its own rect center is
    # NOT the bar center (the bar is one child among Block/Health/Margin) - we must read
    # the HealthBar node itself. The label lives in a CanvasLayer (screen space), so the
    # bar's canvas-space center is pushed through the viewport's canvas transform first;
    # the old code used raw canvas coords as screen offsets AND the sprite center rather
    # than the bar, which drifted the name off-center. Recomputed each hover so it stays
    # correct even if the enemy shifted (e.g. mid hit-reaction knockback).
    var health_bar := stats_ui.get_node_or_null("Health/HealthBar") as Control
    var bar_center_x: float = health_bar.get_global_rect().get_center().x if health_bar \
        else stats_ui.get_global_rect().get_center().x
    var world_y := global_position.y + _name_label_local_y * scale.y
    var screen: Vector2 = get_viewport().get_canvas_transform() * Vector2(bar_center_x, world_y)
    name_label_layer.offset = Vector2(screen.x - NAME_LABEL_WIDTH / 2.0, screen.y)
    name_label.show()


func _on_mouse_exited() -> void:
    name_label.hide()


# EnemyStats.enemy_name wins if set; otherwise derive a readable name from the .tres filename
# (e.g. "goblin_enemy.tres" -> "Goblin", "temple_defender_enemy.tres" -> "Temple Defender" -
# String.capitalize() already turns snake_case into Title Case). Only wrong for the one enemy
# whose file name doesn't match its design name (crab.tres is the design's "Skeleton") - set
# enemy_name explicitly on that one .tres rather than trying to special-case it here.
func _compute_display_name(source_stats: EnemyStats) -> String:
    if source_stats.enemy_name != "":
        return source_stats.enemy_name
    if source_stats.resource_path == "":
        return "Enemy"
    var file_name := source_stats.resource_path.get_file().get_basename()
    return file_name.trim_suffix("_enemy").capitalize()


func set_target_highlight(active: bool) -> void:
    if not _base_sprite_material:
        return
    if _target_highlight_tween and _target_highlight_tween.is_valid():
        _target_highlight_tween.kill()
    # take_damage()'s hit-flash temporarily swaps sprite_2d.material to
    # WHITE_SPRITE_MATERIAL; make sure our own outline shader is the one
    # actually assigned before driving its parameters.
    sprite_2d.material = _base_sprite_material
    if active:
        _base_sprite_material.set_shader_parameter("outline_color", TARGET_HIGHLIGHT_OUTLINE_COLOR)
        _target_highlight_tween = create_tween()
        _target_highlight_tween.tween_property(_base_sprite_material, "shader_parameter/outline_thickness", TARGET_HIGHLIGHT_OUTLINE_THICKNESS, TARGET_HIGHLIGHT_FADE_IN_DURATION)
    else:
        # Instant, unconditional snap to zero — no tween to interrupt or leave
        # at a partial value if this gets called again before a fade finishes.
        # Alpha is zeroed too as a second guarantee of invisibility regardless
        # of thickness, in case anything else nudges thickness back up later.
        _base_sprite_material.set_shader_parameter("outline_thickness", 0.0)
        var faded_color := TARGET_HIGHLIGHT_OUTLINE_COLOR
        faded_color.a = 0.0
        _base_sprite_material.set_shader_parameter("outline_color", faded_color)
   
