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


func _ready() -> void:
    _base_sprite_material = sprite_2d.material as ShaderMaterial



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
        # sprite_2d.position.y is set to sprite_y_offset below - the whole UI stack
        # (intent/HP bar/name/statuses) has to shift by that same amount, or it stays
        # anchored to where the sprite WOULD be at offset 0 while the art itself moves
        # down (most battle files use +10/+20 here). That mismatch is why a Satyr's own
        # legs could hang past its HP bar - the bar was placed too high for where the
        # sprite actually got drawn.
        intent_ui.position.y = -sprite_display_height / 2 - 30 - intent_ui_y_offset + sprite_y_offset
        stats_ui.position.y = (tex_size.y * final_scale / 2) + stats_ui_y_offset + sprite_y_offset
        _name_label_local_y = stats_ui.position.y + stats_ui.size.y + 4
        status_handler.position.y = (tex_size.y * final_scale / 2) + stats_ui.size.y + status_handler_y_offset - 8 + sprite_y_offset
    sprite_2d.position.y = sprite_y_offset

    # Multi-enemy battle scenes (e.g. battles/tier_1_oculus_goblin.tscn) set `scale`
    # directly on the Enemy root to fit several enemies on screen. StatusHandler is a
    # plain child of that root, so it inherited the shrink too - status icons ended up
    # smaller in any multi-enemy fight regardless of enemy size. Counter-scale it so
    # icon size stays constant no matter what the root's own scale is.
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
    # NameLabel's own rect is unscaled screen pixels inside its CanvasLayer (see
    # update_enemy()) - recomputed here rather than cached, so it's always correct even
    # if the enemy shifted (e.g. mid hit-reaction knockback) since update_enemy() last ran.
    var world_center_x = global_position.x + NAME_LABEL_SPRITE_CENTER_X * scale.x
    var world_y = global_position.y + _name_label_local_y * scale.y
    name_label_layer.offset = Vector2(world_center_x - NAME_LABEL_WIDTH / 2.0, world_y)
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
   
