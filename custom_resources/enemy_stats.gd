class_name EnemyStats
extends Stats

@export var ai: PackedScene
# Optional display name for the hover name label (Enemy._get_display_name()). Leave empty to
# fall back to the .tres filename (e.g. "goblin_enemy.tres" -> "Goblin") - only needs to be set
# explicitly when that derived name would be wrong, e.g. "crab" is the design's "Skeleton".
@export var enemy_name: String = ""
