class_name EnemyStats
extends Stats

@export var ai: PackedScene
# Optional display name for the hover name label (Enemy._get_display_name()). Leave empty to
# fall back to the .tres filename (e.g. "goblin_enemy.tres" -> "Goblin") - only needs to be set
# explicitly when that derived name would be wrong, e.g. "crab" is the design's "Skeleton".
@export var enemy_name: String = ""
# Where the art's actual visual content is horizontally centered within its texture
# canvas, as a 0..1 fraction (0.5 = canvas-centered). Used to position the hover
# name label correctly (see Enemy._on_mouse_entered()). -1 = not measured for this
# art yet, falls back to Enemy.NAME_LABEL_SPRITE_CENTER_X's single hand-tuned guess,
# which is only approximately right and was never verified per-enemy.
@export var content_center_x: float = -1.0
