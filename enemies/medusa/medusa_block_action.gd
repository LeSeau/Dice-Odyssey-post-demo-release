extends EnemyAction

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

@export var block := 9


## CADENCE-PROMOTED (2026-08-13, enemy_design_analysis_2026-08.md §9.4).
##
## This beat used to be a weighted pick (4 of 15) capped at "never twice in a row", which made
## Medusa's only ramp an RNG one: in steady state the +3 Muscle landed on ~21% of turns, so how
## fast she grew was luck. It also left her kit as weighted soup with no scannable pulse.
##
## It is now CONDITIONAL on a fixed cadence and NOT in the chance pool at all: she guards on
## turns 3, 7, 11... and never otherwise. Same `fight_turn % 4 == 3` expression as the Skeleton's
## spike (crab/attack_action_2.gd) - the one cadence pattern already validated in playtest, and
## the reason this reads as a deliberate wind-up rather than a coin flip.
##
## The frequency is deliberately near-identical (~21% -> 25%), so this is a legibility change,
## not a balance one: raw DPT moves ~-5% while the ramp goes from ~0.63 Muscle/turn on average to
## a guaranteed 0.75. Slightly softer early, reliably heavier late - which is the whole point.
## Her clock becomes something the player can plan against instead of something they hope about.
##
## The two previous guards are gone because the cadence subsumes both: turns 3/7/11 are never
## consecutive (so she cannot block twice in a row) and none of them is turn 0.
func is_performable() -> bool:
	return Global.fight_turn % 4 == 3


func perform_action() -> void:
	if not enemy or not target:
		return

	var block_effect := BlockEffect.new()
	block_effect.amount = block
	block_effect.sound = sound
	block_effect.execute([enemy])
	var status_effect := StatusEffect.new()
	var muscle := MUSCLE_STATUS.duplicate()
	muscle.stacks = 3
	status_effect.status = muscle
	status_effect.execute([enemy])
	Global.has_blocked_last_turn = true
	get_tree().create_timer(0.6, false).timeout.connect(
		func():
			Events.enemy_action_completed.emit(enemy)
	)
