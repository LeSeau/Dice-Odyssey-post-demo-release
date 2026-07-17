class_name Status
extends Resource

signal status_applied(status: Status)
signal status_changed



enum Type {START_OF_TURN, END_OF_TURN, EVENT_BASED}
enum StackType {NONE, INTENSITY, DURATION}

@export_group("Status Data")
@export var id: String
@export var type: Type
@export var stack_type: StackType
@export var can_expire: bool
@export var duration: int : set = set_duration
@export var stacks: int : set = set_stacks

@export_group("Status Visuals")
@export var icon: Texture
@export_multiline var tooltip: String
# For statuses that repurpose `stacks` as a live progress meter rather than a real
# stack count (Parasite: can_expire=false so it persists all fight, ticking 0..N as the
# player rolls) - hides the icon ENTIRELY while the meter reads 0, instead of showing a
# bare "0" that looks like a broken/empty status. Right for a per-TURN meter like
# Parasite (the enemy's threat is genuinely inert until this turn's rolling starts, so
# there's nothing to telegraph yet) - wrong for a per-FIGHT meter like Greedy, where the
# icon itself IS the information a first-time player needs to see before their first
# roll ("this enemy scales the longer the fight runs"). See hide_counter_when_zero below
# for that case. False for every other status: a real debuff at 0 stacks is already
# pruned by status_ui.gd via can_expire, so this only matters for non-expiring "meter"
# statuses.
@export var hide_when_zero: bool = false
# Narrower than hide_when_zero above: hides only the numeric badge at 0 stacks, leaving
# the icon (and its hover tooltip explaining the mechanic) visible the whole fight - for
# a per-fight meter like Greedy, where the enemy's trait should be legible from turn one
# even though there's nothing to count yet (Julien, 2026-07-16: "should know the
# mechanic before starting his turn"). A bare "0" reads as broken/uninteresting; no
# number at all reads as "this status exists, watch it climb."
@export var hide_counter_when_zero: bool = false

func initialize_status(_target: Node) -> void:
    pass
    
func apply_status(_target: Node) -> void:
    status_applied.emit(self)
    
func get_tooltip() -> String:
    return tooltip
    
func set_duration(new_duration: int) -> void:
    duration = new_duration
    status_changed.emit()
    
func set_stacks(new_stacks: int) -> void:
    stacks = new_stacks
    status_changed.emit()
    
