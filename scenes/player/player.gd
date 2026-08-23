class_name Player
extends Node2D

const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")
# Outline+sway shader shared with enemies (outline disabled here) - the feet-planted
# idle deformation that replaced the AnimationPlayer transform bob (2026-07-23).
const SWAY_SHADER := preload("res://scenes/enemy/enemy.gdshader")

@export var stats: CharacterStats : set = set_character_stats

@onready var sprite_2d: Sprite2D = $SpriteRoot/Sprite2D
@onready var stats_ui: StatsUI = $StatsUI
@onready var status_handler: StatusHandler = $StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Hit-reaction state (knockback + squash), mirrors Enemy.take_damage.
var _hit_pos_tween: Tween
var _hit_squash_tween: Tween
var _hit_rest_position: Vector2
var _hit_rest_sprite_scale: Vector2
var _hit_reaction_active := false
var _sway_material: ShaderMaterial
var _ground_shadow: Sprite2D


func _ready() -> void:
    Global.player = self  # now your card knows who the player is
    status_handler.status_owner = self
    Events.event_damage.connect(_on_event_damage)
    #var infused := preload("res://statuses//infused.tres")
    #infused.duration = 1
    #status_handler.add_status(infused)

    # Feet-planted idle sway (replaces the AnimationPlayer transform bob, which no
    # longer autoplays): boots stay welded to the ground, shoulders/cape lean with the
    # hood trailing a beat, chest rises on the inhale. Hero preset tuned in SCREEN px
    # via the idle_sway_preview A/B (approved by Julien 2026-07-23); the shader wants
    # texture px, hence the divide by the sprite's baked scale. Random phase/speed so
    # the cycle differs per battle.
    _sway_material = ShaderMaterial.new()
    _sway_material.shader = SWAY_SHADER
    var to_tex := 1.0 / sprite_2d.scale.x
    _sway_material.set_shader_parameter("outline_thickness", 0.0)
    _sway_material.set_shader_parameter("anti_aliasing", 0.0)
    _sway_material.set_shader_parameter("sway_px", 4.0 * to_tex)
    _sway_material.set_shader_parameter("head_px", 2.0 * to_tex)
    _sway_material.set_shader_parameter("head_lag", 0.9)
    _sway_material.set_shader_parameter("breathe_px", 3.0 * to_tex)
    _sway_material.set_shader_parameter("margin_px", 6.0 * to_tex)
    _sway_material.set_shader_parameter("sway_hz", 0.19)
    _sway_material.set_shader_parameter("breathe_hz", 0.38)
    _sway_material.set_shader_parameter("sway_phase", randf() * 60.0)
    _sway_material.set_shader_parameter("sway_speed", randf_range(0.9, 1.15))
    sprite_2d.material = _sway_material

    # Align the status row's left edge to the VISIBLE red HP bar, exactly like enemies do
    # (enemy.gd::_update_status_row_x). StatsUI is a centring HBoxContainer whose own left
    # edge sits ~20px LEFT of the bar the player actually sees, so the row's hand-tuned
    # .tscn offset could never line up - it read as starting too far right of the bar.
    status_handler.sort_children.connect(_update_status_row_x)
    stats_ui.sort_children.connect(_update_status_row_x)
    _update_status_row_x()
    _update_ground_shadow()


func _update_status_row_x() -> void:
    if status_handler == null or stats_ui == null:
        return
    var health_bar := stats_ui.get_node_or_null("Health/HealthBar") as Control
    if health_bar == null or health_bar.size.x <= 0.0:
        return
    status_handler.position.x = to_local(health_bar.global_position).x


# Ground shadow, mirroring Enemy's (enemy.gd::update_enemy). Every enemy builds one and the
# player never did. With the old chibi - a dark, wide, bottom-heavy silhouette - the omission
# was invisible; the 2026-08 hero art has a narrower stance and pale legs, so he read as
# hovering next to enemies that are visibly planted.
#
# Child of the ROOT and moved to index 0 so it draws under SpriteRoot. Note the deliberate
# difference from Enemy: the player's knockback tweens the root (_play_hit_reaction), so the
# shadow travels with the recoil - correct, since the body is genuinely shoved backwards. The
# squash tweens sprite_2d.scale and the idle is a shader deformation, so neither drags it.
# Texture and content-rect come from Enemy's cached statics, so both stay in sync by
# construction if those are ever retuned.
func _update_ground_shadow() -> void:
    if sprite_2d == null or sprite_2d.texture == null:
        return
    if _ground_shadow == null:
        _ground_shadow = Sprite2D.new()
        _ground_shadow.texture = Enemy._get_shadow_texture()
        add_child(_ground_shadow)
        move_child(_ground_shadow, 0)
    var tex_size: Vector2 = sprite_2d.texture.get_size()
    var content: Rect2 = Enemy._get_content_rect(sprite_2d.texture)
    # Feet are the bottom-centre of the INK, not of the canvas - the art is padded.
    var feet := Vector2(
            content.get_center().x - tex_size.x / 2.0,
            content.end.y - tex_size.y / 2.0)
    _ground_shadow.position = to_local(sprite_2d.to_global(feet)) + Vector2(0.0, 5.0)
    var shadow_width: float = content.size.x * sprite_2d.scale.x * 0.82
    _ground_shadow.scale = Vector2(shadow_width / 256.0, shadow_width * 0.24 / 256.0)



func set_character_stats(value: CharacterStats) -> void:
    stats = value
    
    if not stats.stats_changed.is_connected(update_stats):
        stats.stats_changed.connect(update_stats)

    update_player()


func update_player() -> void:
    if not stats is CharacterStats: 
        return
    if not is_inside_tree(): 
        await ready

    sprite_2d.texture = stats.art
    _update_ground_shadow()
    update_stats()


func update_stats() -> void:
    stats_ui.update_stats(stats)


func take_damage(damage: int, which_modifier: Modifier.Type) -> void:
    if stats.health <= 0:
        return

    sprite_2d.material = WHITE_SPRITE_MATERIAL
    var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
    # Display (and stats) report what reaches HP, not the raw attack: block soaks first.
    # Mirrors the exact clamp stats.take_damage applies right below.
    Global.blocked_to_display = mini(stats.block, modified_damage)
    Global.damage_to_display = modified_damage - Global.blocked_to_display

    _play_hit_reaction()
    stats.take_damage(modified_damage)
    Events.hp_changed.emit()

    # Short, sharp white flash (was 0.17s). Restore the sway material, NOT null -
    # null would permanently freeze the idle deformation after the first hit taken.
    var flash_tween := create_tween()
    flash_tween.tween_interval(0.06)
    flash_tween.tween_callback(
        func():
            sprite_2d.material = _sway_material
            if stats.health <= 0:
                Events.player_died.emit()
                queue_free()
    )


# Knockback + squash on hit. self.position and Sprite2D.scale are both free of the idle
# (a shader-side deformation since 2026-07-23 - nothing animates SpriteRoot anymore),
# so neither tween fights it.
func _play_hit_reaction() -> void:
    if not _hit_reaction_active:
        _hit_rest_position = position
        _hit_rest_sprite_scale = sprite_2d.scale
        _hit_reaction_active = true

    if _hit_pos_tween and _hit_pos_tween.is_valid():
        _hit_pos_tween.kill()
    if _hit_squash_tween and _hit_squash_tween.is_valid():
        _hit_squash_tween.kill()

    # Player sits to the left of the enemies, so recoils leftward (-x).
    _hit_pos_tween = create_tween()
    _hit_pos_tween.tween_property(self, "position", _hit_rest_position + Vector2(-16, 0), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_pos_tween.tween_property(self, "position", _hit_rest_position, 0.3) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _hit_pos_tween.tween_callback(func(): _hit_reaction_active = false)

    _hit_squash_tween = create_tween()
    _hit_squash_tween.tween_property(sprite_2d, "scale", Vector2(_hit_rest_sprite_scale.x * 1.15, _hit_rest_sprite_scale.y * 0.85), 0.05) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _hit_squash_tween.tween_property(sprite_2d, "scale", _hit_rest_sprite_scale, 0.28) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_event_damage(amount):
    print("taking damage from event")
