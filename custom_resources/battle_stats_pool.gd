class_name BattleStatsPool
extends Resource

@export var pool: Array [BattleStats]
var total_weights_by_tier := [0.0, 0.0, 0.0, 0.0, 0.0]

# Add a simple array to track used battle stats
var used_battles: Array[BattleStats] = []

func _get_all_battles_for_tier(tier: int) -> Array[BattleStats]:
    return pool.filter(
        func(battle: BattleStats):
            return battle.battle_tier == tier
    )

func _setup_weight_for_tier(tier: int) -> void:
    var battles := _get_all_battles_for_tier(tier)
    total_weights_by_tier[tier] = 0.0
    
    for battle: BattleStats in battles:
        # Skip battles that have already been used
        if used_battles.has(battle):
            continue
            
        total_weights_by_tier[tier] += battle.weight
        battle.accumulated_weight = total_weights_by_tier[tier]
        
func get_random_battle_for_tier(tier: int) -> BattleStats:
    # If we've recalculated weights and there are none, all battles have been used
    if total_weights_by_tier[tier] <= 0.0:
        # Reset used battles for this tier
        var tier_battles := _get_all_battles_for_tier(tier)
        for battle in tier_battles:
            if used_battles.has(battle):
                used_battles.erase(battle)
        
        # Recalculate weights
        _setup_weight_for_tier(tier)
        
        # If still no weights, something is wrong
        if total_weights_by_tier[tier] <= 0.0:
            return null
    
    var roll := randf_range(0.0, total_weights_by_tier[tier])
    var battles := _get_all_battles_for_tier(tier)
    
    for battle: BattleStats in battles:
        # Skip battles that have already been used
        if used_battles.has(battle):
            continue
            
        if battle.accumulated_weight > roll:
            # Add to used battles
            used_battles.append(battle)
            
            # Recalculate weights for this tier since we've used a battle
            _setup_weight_for_tier(tier)
            
            return battle
    
    return null
    
func setup() -> void:
    # Clear used battles at the start of a run
    used_battles.clear()
    
    # Set up weights for each tier
    for i in 4:
        _setup_weight_for_tier(i)
