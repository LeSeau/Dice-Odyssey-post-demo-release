class_name BattleStats
extends Resource

@export_range (0, 4) var battle_tier: int
@export_range (0.0, 10.0) var weight: float
@export var gold_reward_min: int
@export var gold_reward_max: int
@export var enemies: PackedScene
@export var group: String = ""
## Which act may serve this fight. 0 = any act (every fight authored before this field
## existed, which is why 0 is the default). 1 = act 1 only, 2 = act 2 only.
## Act 2 still recycles the act-1 pool through run.gd::ACT2_SOURCE_TIER, so this is what
## lets an act-2-only fight sit in the same pool without leaking back into act 1.
## WARNING: this is a new @export. An editor left open with a stale copy of this script
## will strip "act = 2" from the .tres files on its next re-save, and those fights would
## silently return to act 1. Restart the editor before playing.
@export_range(0, 2) var act: int = 0

var accumulated_weight: float = 0.0

func roll_gold_reward() -> int:
    return randi_range(gold_reward_min, gold_reward_max)
