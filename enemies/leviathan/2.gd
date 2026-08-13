extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 8


## CADENCE-PROMOTED (2026-08-13, enemy_design_analysis_2026-08.md §9.4).
##
## Was a weighted pick (4 of 14) capped at "never twice in a row", so the boss's only ramp landed
## on ~22% of turns in steady state - his escalation was luck. It is now CONDITIONAL and out of
## the chance pool entirely: he guards on a fixed beat and never otherwise, which makes the whole
## fight scannable ("he winds up every fourth turn") at essentially unchanged frequency (~22% ->
## 25%): DPT ~-3.5%, ramp 0.89 -> 1.0 Muscle/turn guaranteed.
##
## ⚠️ WHY `% 4 == 2` AND NOT THE SKELETON/MEDUSA `% 4 == 3`: this AI scene is shared with the
## act-2 Dicelord, whose signature theft is CONDITIONAL on `fight_turn % 3 == 1`. Two conditional
## cadences on moduli 4 and 3 collide every 12 turns, and the picker resolves a collision by
## child order - one of the two beats is silently dropped. With `% 4 == 3` the first collision is
## turn 7, squarely inside the boss's 6-9 turn target; with `% 4 == 2` it moves to turn 10, past
## it. dice_theft is also ordered BEFORE this node in the scene so that when turn 10 IS reached,
## theft wins and the guard is what gets skipped - the boss's identity move always beats his
## metronome. Change either modulus and you have to redo this collision math.
func is_performable() -> bool:
	return Global.fight_turn % 4 == 2


func perform_action() -> void:
	if not enemy or not target:
		return

	var block_effect := BlockEffect.new()
	block_effect.amount = block
	block_effect.sound = sound
	block_effect.execute([enemy])
	var status_effect := StatusEffect.new()
	var muscle := MUSCLE_STATUS.duplicate()
	muscle.stacks = 4
	status_effect.status = muscle
	status_effect.execute([enemy])
	Global.has_blocked_last_turn = true

	get_tree().create_timer(0.6, false).timeout.connect(
		func():
			Events.enemy_action_completed.emit(enemy)
	)
