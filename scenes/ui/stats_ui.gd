class_name StatsUI
extends HBoxContainer

@onready var block: Control = %Block
@onready var block_label: Label = %BlockLabel
@onready var health: HBoxContainer = $Health
@onready var health_label: Label = %HealthLabel

@onready var health_bar: ProgressBar = %HealthBar
@onready var chip_bar: ProgressBar = %ChipBar

# Slay-the-Spire-style damage feedback. ChipBar sits BEHIND HealthBar (show_behind_parent)
# and carries the bar's dark background; HealthBar's own background is a StyleBoxEmpty so
# the chip shows through. On damage the red bar snaps to the new value, exposing a bright
# amber band of "just lost" health, which then drains away to meet it. Healing and the
# first update snap both bars so nothing ever animates backwards.
const CHIP_HOLD := 0.18
const CHIP_DRAIN_TIME := 0.45

# The block badge straddles the bar's left edge, so its number has to fit a 34px shield.
# MinionPro at 20 fits two digits comfortably; three or more need stepping down or they
# spill outside the shield entirely (999 used to render about twice the badge's width).
const BLOCK_FONT_SIZES := {1: 20, 2: 20, 3: 15}
const BLOCK_FONT_SIZE_TINY := 12

var _chip_tween: Tween
var _bars_initialized := false


func update_stats(stats: Stats) -> void:
    block_label.text = str(stats.block)
    _fit_block_label(block_label.text.length())
    health_label.text = str(stats.health) + "/" + str(stats.max_health)

    # max_value must be set BEFORE value: ProgressBar clamps value against the
    # CURRENT max at assignment time, so the old order silently capped the fill
    # at the previous max whenever max_health grows mid-fight (never happened
    # before the act-2 spawn scaling: label said 149/149, bar showed 85/149).
    health_bar.max_value = stats.max_health
    chip_bar.max_value = stats.max_health

    var previous: float = health_bar.value
    health_bar.value = stats.health
    _update_chip(previous, float(stats.health))

    # Only show/hide the contents, not the container itself
    for child in block.get_children():
        child.visible = stats.block > 0

    health.visible = stats.health > 0


func _update_chip(previous: float, current: float) -> void:
    if not _bars_initialized:
        # First paint: the bar is being populated, not damaged.
        _bars_initialized = true
        chip_bar.value = current
        return

    if current > previous:
        # Healing - the chip must never sit below the red bar, or the band would
        # appear on the wrong side of it.
        _kill_chip_tween()
        chip_bar.value = current
        return

    if is_equal_approx(current, previous):
        # No health change (block or max_health moved). Leave a running drain alone.
        return

    _kill_chip_tween()
    # Keep whatever the chip is still showing from an earlier, unfinished drain, so
    # rapid multi-hits widen the band instead of restarting it lower each time.
    chip_bar.value = maxf(chip_bar.value, previous)
    _chip_tween = create_tween()
    _chip_tween.tween_interval(CHIP_HOLD)
    _chip_tween.tween_property(chip_bar, "value", current, CHIP_DRAIN_TIME) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _kill_chip_tween() -> void:
    if _chip_tween and _chip_tween.is_valid():
        _chip_tween.kill()


# LabelSettings is a shared sub-resource, so it is duplicated per instance before the
# font size is touched - mutating it in place would resize the badge on every other
# StatsUI in the fight too.
func _fit_block_label(digits: int) -> void:
    var target: int = BLOCK_FONT_SIZES.get(digits, BLOCK_FONT_SIZE_TINY)
    if block_label.label_settings == null:
        return
    if block_label.label_settings.font_size == target:
        return
    block_label.label_settings = block_label.label_settings.duplicate()
    block_label.label_settings.font_size = target
