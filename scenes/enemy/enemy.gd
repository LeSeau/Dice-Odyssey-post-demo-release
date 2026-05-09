class_name Enemy
extends Area2D

const ARROW_OFFSET := 5
const WHITE_SPRITE_MATERIAL := preload("res://art/white_sprite_material.tres")

@export var stats: EnemyStats : set = set_enemy_stats
@export var width: int 
@export var height: int
@onready var sprite_2d: Sprite2D = $SpriteRoot/Sprite2D


@onready var arrow: Sprite2D = $Arrow
@onready var stats_ui: StatsUI = $StatsUI
@onready var intent_ui: IntentUI = $IntentUI
@onready var status_handler: StatusHandler = $StatusHandler
@onready var modifier_handler: ModifierHandler = $ModifierHandler


var enemy_action_picker: EnemyActionPicker
var current_action: EnemyAction : set = set_current_action

var last_action: String = ""
var last_action_count: int = 0
var blocked_last_turn: bool = false



func set_current_action(value: EnemyAction) -> void:
    current_action = value
    update_intent()


func set_enemy_stats(value: EnemyStats) -> void:
    stats = value.create_instance()
    
    if not stats.stats_changed.is_connected(update_stats):
        stats.stats_changed.connect(update_stats)
        stats.stats_changed.connect(update_action)
        Events.enemy_strength_changed.connect(update_intent)
        
    
    update_enemy()


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
    
    if not current_action:
        current_action = enemy_action_picker.get_action()
        return
    
    var new_conditional_action := enemy_action_picker.get_first_conditional_action()
    if new_conditional_action and current_action != new_conditional_action:
        current_action = new_conditional_action


const MAX_ENEMY_WIDTH := 256.0
const MAX_ENEMY_HEIGHT := 256.0

func update_enemy() -> void:
    if not stats is Stats:
        return
    if not is_inside_tree():
        await ready

    sprite_2d.texture = stats.art

    var tex_size = sprite_2d.texture.get_size()

    # Fallback defaults if not set in inspector
    var target_width := width if width > 0 else 256
    var target_height := height if height > 0 else 256

    if tex_size.x > 0 and tex_size.y > 0:
        var width_scale = target_width / tex_size.x
        var height_scale = target_height / tex_size.y
        var final_scale = min(width_scale, height_scale)
        sprite_2d.scale = Vector2(final_scale, final_scale)

    arrow.position = Vector2.RIGHT * (sprite_2d.get_rect().size.x * sprite_2d.scale.x / 2 + ARROW_OFFSET)

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
    var tween := create_tween()
    tween.tween_callback(Shaker.shake.bind(self, 16, 0.15))
    tween.tween_callback(stats.take_damage.bind(modified_damage))
    tween.tween_interval(0.17)

    tween.finished.connect(
        func():
            sprite_2d.material = null
            
            if stats.health <= 0:
                Events.enemy_died.emit(self)
                var death_tween := create_tween()
                death_tween.tween_property(self, "modulate:a", 0.0, 0.4)
                death_tween.tween_callback(queue_free)
    )


func _on_area_entered(_area: Area2D) -> void:
    arrow.hide()


func _on_area_exited(_area: Area2D) -> void:
    arrow.hide()
   
