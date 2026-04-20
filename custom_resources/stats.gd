class_name Stats
extends Resource

signal stats_changed

@export var max_health := 65
@export var art: Texture

var health: int : set = set_health
var block: int : set = set_block

func _ready() -> void:
    Events.event_damage.connect(_on_event_damage)



func set_health(value : int) -> void:
    health = clampi(value, 0, max_health)
    Global.player_hp = health
    stats_changed.emit()


func set_block(value : int) -> void:
    block = clampi(value, 0, 999)
    stats_changed.emit()


func take_damage(damage : int) -> void:
    if damage <= 0:
        return
    var initial_damage = damage
    damage = clampi(damage - block, 0, damage)
    self.block = clampi(block - initial_damage, 0, block)
    self.health -= damage
    Global.player_hp = self.health
    Events.hp_changed.emit()


func heal(amount : int) -> void:
    self.health += amount
    Global.player_hp = self.health


func create_instance() -> Resource:
    var instance: Stats = self.duplicate()
    instance.health = max_health
    Global.player_hp = instance.health
    instance.block = 0
    return instance

    
func _on_event_damage(amount):
    print("taking damage from event")
    print(amount)
    take_damage(10)
    self.health -= 10
    Global.player_hp -= amount
    stats_changed.emit()
    
