class_name BattleReward
extends Control

#enum Type {GOLD, NEW_CARD, RELIC}

# Set by run.gd (_on_battle_won) based on the room just cleared, before add_card_reward() is
# ever clicked - see _rarity_source()/_show_card_rewards() for how each context changes
# the draw. Event-triggered rewards (Wandering Merchant etc., via run.gd::_on_show_reward)
# never set this, so they default to NORMAL - correct, those shouldn't get elite/boss odds.
enum RewardContext {NORMAL, ELITE, BOSS}
@export var reward_context: RewardContext = RewardContext.NORMAL

# Per-card chance that a reward offer arrives already upgraded, ported from STS2's
# CardFactory.RollForUpgrade: `actIndex * UpgradedCardOddScaling` with scaling 0.25, so
# act 1 = 0%, act 2 = 25% (the reference's act 3 = 50% has no equivalent here yet). The roll
# happens AFTER rarity is known and is skipped for Rares - in the reference the act bonus is
# only added when `card.Rarity != Rare`, which also means boss screens (all-Rare) never hand
# out pre-upgraded cards. Shop cards are never upgraded either; the reference passes an
# enormous negative base chance there, ours simply doesn't roll.
const UPGRADED_CARD_ODDS_SCALING := 0.25

const CARD_REWARDS = preload("res://scenes/ui/card_rewards.tscn")
const REWARD_BUTTON = preload("res://scenes/ui/reward_button.tscn")
const GOLD_ICON := preload("res://gold_icon_v2.png")
const GOLD_TEXT := "%s Gold"
const CARD_ICON := preload("res://card_cover_ok.png")
const CARD_TEXT := "Add New Card"

var relic_tooltip_instance: CanvasLayer
const TooltipScene = preload("res://scenes/ui/tooltip.tscn")

# Secondary keyword tooltips (e.g. "Scout" next to a relic's own description) - this screen
# never had these at all before, unlike relic_ui.gd's hover (a separate, simpler tooltip system
# for reward buttons specifically). Mirrors relic_ui.gd's pattern.
const TOOLTIP_OFFSET_X = 8
const TOOLTIP_HEIGHT = 108
const TOOLTIP_SPACING = 1
var relic_tooltip_instances_tags: Array = []
var _relic_hover_id := 0

var warning_dismissed := false
const UNCLAIMED_WARNING := "You still have rewards to claim!"
# Only card rows that were never opened are left (Julien, 2026-09-24: warn when the player
# leaves "without having picked a card and not even seen what they are").
const UNSEEN_CARDS_WARNING := "You haven't even looked at your new cards!"

# Win -> rewards flow (see the header of reward_flow.gd for the numbered ideas).
const RewardFlow := preload("res://scenes/battle_reward/reward_flow.gd")
# Idea 1: set by run.gd::_show_reward_view BEFORE add_child when this screen is pushed over
# the room it came from instead of replacing it.
var over_live_room := false
# Rows are tagged with metas: "card_row" (a card reward), "seen" (its picker was opened at
# least once), "offer" (the three cards it rolled), "claimed", "skipped".
var _gold_row: Control = null
var _gold_counter_pending := false
var _done := false
var _leaving := false
# Idea 8: things still flying (gold to the counter, a card to the deck, a relic to the bar,
# the room coming back up). The screen leaves on its own once every reward is taken AND
# this is back to 0, so the payoff is seen before the curtain.
var _flights_in_air := 0
const DONE_FADE_TIME := 0.25
const DONE_ROOM_UP_TIME := 0.45
# After the last landing, so the counter or the deck button reads before the curtain.
const LANDING_BEAT := 0.15

@export var run_stats: RunStats
@export var character_stats: CharacterStats
@export var relic_handler: RelicHandler

@onready var rewards: VBoxContainer = %Rewards
@onready var reward_panel: VBoxContainer = $VBoxContainer
@onready var background: TextureRect = $Background
@onready var background_dimmer: ColorRect = $BackgroundDimmer
@onready var title_label: Label = $VBoxContainer/Label
@onready var reward_container: PanelContainer = $VBoxContainer/RewardContainer
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

@onready var warning_panel: Panel = $WarningPanel
@onready var warning_label: Label = $WarningPanel/WarningLabel
@onready var confirm_button: Button = $WarningPanel/ConfirmButton
@onready var gg_panel: Panel = $GGPanel
@onready var gg_label_title: Label = $GGPanel/GGLabelTitle
@onready var gg_label_text: RichTextLabel = $GGPanel/GGLabelText
@onready var join_discord_control: Control = $GGPanel/JoinDiscordControl
@onready var continue_act_2_button: Button = $GGPanel/ContinueAct2Button
@onready var gg_run_stats: PanelContainer = $GGPanel/GGRunStats
@onready var gg_main_menu_button: Button = $GGPanel/GGMainMenuButton


func _ready() -> void:
    for node: Node in rewards.get_children():
        node.queue_free()

    # Mirror the battle just fought instead of always showing the .tscn's static
    # default - null before any battle has happened yet this run (see Global's doc
    # comment), in which case the authored default texture stays as-is.
    if Global.last_battle_background:
        background.texture = Global.last_battle_background

    run_stats = RunStats.new()
    Events.gold_changed.connect(func():print("gold:%s" % Global.gold))
    
    character_stats = preload("res://characters/warrior/warrior.tres").create_instance()

    audio_player.stream = load("res://success.mp3")
    # Idea 4: after a fight the jingle already rang on the win beat (reward_flow.gd::on_win).
    # Event and chest rewards have no win beat, so they still ring it here.
    if RewardFlow.jingle_played:
        RewardFlow.jingle_played = false
    else:
        audio_player.play()
    _apply_reward_flow_backdrop()
    # Show GG panel if a boss was defeated: after the act-1 boss it becomes the
    # act-transition panel (retitled + Continue to Act 2 button), after the act-2
    # boss it stays the final "run complete" panel authored in the .tscn (plus the
    # Main Menu button, hidden by default). Both variants share the run-stats
    # scoreboard and the Discord CTA.
    if Global.is_final_boss_fight:
        if Global.current_act == 1:
            _setup_act_transition_panel()
        else:
            gg_main_menu_button.show()
        gg_main_menu_button.pressed.connect(_on_gg_main_menu_button_pressed)
        _show_gg_panel()
        Global.is_final_boss_fight = false
    else:
        gg_panel.hide()

    _play_entrance_sequence()

const BACKDROP_FADE_DURATION := 0.3
const FRAME_FADE_DELAY := 0.16
const FRAME_FADE_DURATION := 0.42
const REWARD_ENTRANCE_BASE_DELAY := 0.4
const REWARD_ENTRANCE_STAGGER := 0.14
const REWARD_ENTRANCE_DURATION := 0.4
const REWARD_ENTRANCE_START_SCALE := 0.94

# Counts reward buttons as they're registered (add_gold_reward/add_card_reward/
# add_relic_reward, called by run.gd right after this scene is created) so each one
# gets its own stagger slot in the entrance below.
var _reward_entrance_index := 0

# Three-beat reveal instead of the old single flat fade on the whole panel: backdrop
# settles in first, then the frame (title/box/back button), then each reward button
# pops in on its own with a short stagger. Reads as "the rewards are being revealed"
# rather than "a panel appeared". Kept to alpha + a subtle scale, no rise/bounce -
# Julien already called an earlier "rises up like a trophy" version too much once
# actually played.
func _play_entrance_sequence() -> void:
    reward_panel.modulate.a = 1.0
    _reward_entrance_index = 0

    # The swap fallback's background shows the same room the fight just showed, so it is
    # opaque from the first frame: fading it in from 0 is what flashed Godot's grey clear
    # colour. Over the live room it is hidden (_apply_reward_flow_backdrop) and only the
    # dimmer fades in.
    background.modulate.a = 1.0
    background_dimmer.modulate.a = 0.0
    var backdrop_tween := create_tween()
    backdrop_tween.tween_property(background_dimmer, "modulate:a", 1.0, BACKDROP_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    title_label.modulate.a = 0.0
    reward_container.modulate.a = 0.0
    back_button.modulate.a = 0.0
    var frame_tween := create_tween()
    frame_tween.tween_interval(FRAME_FADE_DELAY)
    frame_tween.tween_property(title_label, "modulate:a", 1.0, FRAME_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    frame_tween.parallel().tween_property(reward_container, "modulate:a", 1.0, FRAME_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    frame_tween.parallel().tween_property(back_button, "modulate:a", 1.0, FRAME_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Queues an individual reveal for a reward button. Called right after each
# add_*_reward() queues its rewards.add_child.call_deferred(...) - deferring the
# animation start too (in that same order) guarantees the button already exists in
# the tree by the time this runs.
func _register_reward_entrance(button: Control) -> void:
    var index := _reward_entrance_index
    _reward_entrance_index += 1
    _animate_reward_entrance.call_deferred(button, index)

func _animate_reward_entrance(button: Control, index: int) -> void:
    if not is_instance_valid(button):
        return
    button.modulate.a = 0.0
    button.scale = Vector2(REWARD_ENTRANCE_START_SCALE, REWARD_ENTRANCE_START_SCALE)
    # One more frame so the VBoxContainer has actually sorted/sized this button -
    # otherwise button.size can still be last frame's (or zero), throwing off the
    # center pivot below. Invisible either way since alpha is already 0.
    await get_tree().process_frame
    if not is_instance_valid(button):
        return
    button.pivot_offset = button.size / 2.0
    _reward_flow_row_entrance(button, REWARD_ENTRANCE_BASE_DELAY + index * REWARD_ENTRANCE_STAGGER)
    var tween := button.create_tween()
    tween.tween_interval(REWARD_ENTRANCE_BASE_DELAY + index * REWARD_ENTRANCE_STAGGER)
    tween.tween_property(button, "modulate:a", 1.0, REWARD_ENTRANCE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(button, "scale", Vector2.ONE, REWARD_ENTRANCE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func add_gold_reward(amount: int) -> void:
    var gold_reward := REWARD_BUTTON.instantiate() as RewardButton
    gold_reward.custom_minimum_size.y = 70
    gold_reward.reward_icon = GOLD_ICON
    gold_reward.reward_text = GOLD_TEXT % amount
    gold_reward.pressed.connect(on_gold_reward_taken.bind(amount, gold_reward))
    _gold_row = gold_reward
    rewards.add_child.call_deferred(gold_reward)
    _register_reward_entrance(gold_reward)

func add_card_reward() -> void:
    var card_reward := REWARD_BUTTON.instantiate() as RewardButton
    card_reward.custom_minimum_size.y = 70
    card_reward.reward_icon = CARD_ICON
    card_reward.reward_text = CARD_TEXT
    card_reward.pressed.connect(_show_card_rewards.bind(card_reward))
    card_reward.set_meta("card_row", true)
    rewards.add_child.call_deferred(card_reward)
    _register_reward_entrance(card_reward)

func add_relic_reward(relic: Relic) -> void:
    var relic_reward := REWARD_BUTTON.instantiate() as RewardButton
    relic_reward.reward_icon = relic.icon
    relic_reward.reward_text = relic.relic_name

    # Connect hover signals to show/hide tooltip
    relic_reward.mouse_entered.connect(_on_relic_reward_mouse_entered.bind(relic, relic_reward))
    relic_reward.mouse_exited.connect(_on_relic_reward_mouse_exited)

    relic_reward.pressed.connect(_on_relic_reward_taken.bind(relic, relic_reward))
    rewards.add_child.call_deferred(relic_reward)
    _register_reward_entrance(relic_reward)


# Tooltips live under get_tree().root, not this node - free them explicitly whenever this
# screen itself is torn down, otherwise a still-hovered tooltip can leak into whatever screen
# comes next (same bug class as relic_ui.gd's, see its _exit_tree() comment).
func _exit_tree() -> void:
    _cleanup_relic_tooltips()
    # Leaving before the first gold coin landed must not leave the counter stale.
    _release_gold_counter()

func _cleanup_relic_tooltips() -> void:
    if relic_tooltip_instance and is_instance_valid(relic_tooltip_instance):
        relic_tooltip_instance.queue_free()
        relic_tooltip_instance = null
    for tooltip in relic_tooltip_instances_tags:
        if tooltip and is_instance_valid(tooltip):
            tooltip.queue_free()
    relic_tooltip_instances_tags.clear()

# Called when mouse enters a relic reward button
func _on_relic_reward_mouse_entered(relic: Relic, button: Control) -> void:
    _cleanup_relic_tooltips()
    _relic_hover_id += 1
    var my_id := _relic_hover_id

    relic_tooltip_instance = TooltipScene.instantiate()
    Global.add_tooltip(relic_tooltip_instance, self)

    # Get the Tooltip panel child
    var tooltip_panel = relic_tooltip_instance.get_node("Tooltip")

    # Set tooltip title + text
    tooltip_panel.tooltip_title.text = "[color=gold][b]%s[/b][/color]" % relic.relic_name
    # See relic_ui.gd's _fit_tooltip_title for why: the title box is fixed-width and
    # doesn't grow to fit, so a long name (e.g. "Cartographer's Quill") gets clipped.
    if relic.relic_name.length() > 20:
        tooltip_panel.tooltip_title.add_theme_font_size_override("bold_font_size", 11)
    elif relic.relic_name.length() > 15:
        tooltip_panel.tooltip_title.add_theme_font_size_override("bold_font_size", 13)
    tooltip_panel.tooltip_label.text = relic.get_colorized_description(relic.tooltip)

    # Secondary keyword tooltips (e.g. "Scout"), through the same shared ordering as relic_ui.gd
    # and the card hovers - tags, dice types and Power, in the order the relic's text mentions
    # them. Resolved before placing anything: the tooltip and its keyword column are laid out
    # as ONE group, so the pair only gets pushed left as far as it needs to fit. The column
    # alone used to run 32px off the right edge here - reward buttons are 496px wide inside a
    # centred 550px panel, leaving less room on the right than two stacked panels need.
    var tags_to_show: Array = KeywordColorizer.ordered_description_keywords(
        relic.tooltip, relic.tags)

    var group_width := Global.TOOLTIP_PANEL_SIZE.x
    if not tags_to_show.is_empty():
        group_width += TOOLTIP_OFFSET_X + Global.TOOLTIP_PANEL_SIZE.x
    var pos := Vector2(
        Global.tooltip_group_x(button.get_global_position().x, button.get_size().x, group_width),
        button.get_global_position().y)
    tooltip_panel.show_tooltip(pos)

    if tags_to_show.is_empty():
        return

    # Wait a frame so the main tooltip panel has its real size before positioning off of it
    # (same gotcha relic_ui.gd already worked around).
    await get_tree().create_timer(0.5).timeout
    if my_id != _relic_hover_id:
        return

    var start_y := Global.tooltip_column_y(pos.y + (tooltip_panel.size.y / 2.0),
        tags_to_show.size(), TOOLTIP_HEIGHT, TOOLTIP_SPACING)
    # x already reserved for this column by the group placement above.
    var base_pos := Vector2(pos.x + tooltip_panel.size.x + TOOLTIP_OFFSET_X, start_y)
    var captured_id := my_id

    for i in range(tags_to_show.size()):
        var tag_tooltip = TooltipScene.instantiate()
        Global.add_tooltip(tag_tooltip, self)
        var tag_panel = tag_tooltip.get_node("Tooltip")
        tag_panel.get_tooltip_content(tags_to_show[i])
        var tag_pos = (base_pos + Vector2(0, i * (TOOLTIP_HEIGHT + TOOLTIP_SPACING))).round()
        tag_panel.show_tooltip(tag_pos)
        relic_tooltip_instances_tags.append(tag_tooltip)

    get_tree().create_timer(6.0).timeout.connect(func():
        if captured_id == _relic_hover_id:
            _cleanup_relic_tooltips()
    )

# Called when mouse exits the relic reward button
func _on_relic_reward_mouse_exited() -> void:
    _relic_hover_id += 1
    _cleanup_relic_tooltips()

func _show_card_rewards(row: Control = null) -> void:
    if not run_stats or not character_stats:
        return

    var card_rewards := CARD_REWARDS.instantiate() as CardRewards
    add_child(card_rewards)
    # The row travels with the pick: an event can put two card rows on one screen
    # (event_relic_or_cards.gd), and each one is claimed or skipped on its own.
    card_rewards.card_reward_selected.connect(_on_card_reward_taken.bind(row))

    # Hide the rewards panel while the picker overlay is up - its "REWARDS" title used to
    # ghost through the picker's dimmers right behind the "Choose a card" banner. Restored
    # in _on_card_reward_taken, which fires for both pick and skip.
    reward_panel.hide()
    # Same treatment for the RelicBar (and the Discord pin): the "Choose a card" banner renders
    # at y 102..187 and the relic row occupies y 90..126, so a late-run collection lands right

    # Idea 7: each row rolls its offer ONCE and keeps it, so reopening the row after a Skip
    # shows the same three cards. Rolling again here would turn Skip into a free reroll.
    if is_instance_valid(row):
        row.set_meta("seen", true)
        if row.has_meta("offer"):
            card_rewards.rewards = row.get_meta("offer")
            card_rewards.show()
            return

    var card_reward_array: Array[Card] = []
    var available_cards: Array[Card] = character_stats.draftable_cards.cards.duplicate(true)
    var owned_cards: Array[Card] = character_stats.deck.cards

    # One independent roll per slot, each advancing the run's rare offset immediately - that
    # per-CARD reset is what stops two Rares landing side by side (see CardRarityDraw).
    # Boss needs no special case any more: its odds row is a flat 1.0 Rare, so it fills all
    # three slots, and because each Rare resets the offset it also leaves pity at the floor
    # afterwards - which the old dedicated boss branch never did.
    var source := _rarity_source()
    for i in range(3):
        var tier := CardRarityDraw.roll_rarity(source, run_stats.rare_offset)
        # Advanced off the ROLL, not off whether a card was found: the reference moves the
        # offset inside Roll(), before anything is drawn from the pool.
        run_stats.rare_offset = CardRarityDraw.advance_offset(run_stats.rare_offset, tier)
        var picked_card := CardRarityDraw.pick_card(available_cards, tier, owned_cards)
        if picked_card:
            available_cards.erase(picked_card)
            card_reward_array.append(_resolve_reward_card(picked_card))

    Global.force_upgraded_card_rewards = false
    if is_instance_valid(row):
        row.set_meta("offer", card_reward_array)
    card_rewards.rewards = card_reward_array
    card_rewards.show()


func _resolve_reward_card(picked_card: Card) -> Card:
    if not picked_card.can_be_upgraded():
        return picked_card
    # Wandering Merchant's paid browse is an unconditional override that predates the odds
    # roll - it upgrades Rares too, which is the whole point of paying for it.
    if Global.force_upgraded_card_rewards:
        return picked_card.upgraded_version
    if picked_card.rarity_tier == Card.RarityTier.RARE:
        return picked_card
    # Explicitly typed: Global.current_act is an autoload field, and `:=` off one of those is
    # the documented way to silently break this whole file's parse.
    var act_index: int = maxi(Global.current_act - 1, 0)
    if randf() < float(act_index) * UPGRADED_CARD_ODDS_SCALING:
        return picked_card.upgraded_version
    return picked_card


# RewardContext is "which room did we just clear" (set by run.gd off the map); Source is
# "which odds row does that map to". Deliberately two enums: the shop is a rarity source but
# never a reward context.
func _rarity_source() -> CardRarityDraw.Source:
    match reward_context:
        RewardContext.BOSS:
            return CardRarityDraw.Source.BOSS
        RewardContext.ELITE:
            return CardRarityDraw.Source.ELITE
        _:
            return CardRarityDraw.Source.NORMAL


func _on_card_reward_taken(card: Card, row: Control = null) -> void:
    # Before the null guard - the panel must come back on skip too. Not after the LAST pick:
    # the screen is leaving (idea 8), and the panel would only pop back to fade out again.
    var last_pick := card != null and is_instance_valid(row) and not row.has_meta("claimed") \
        and _unclaimed_rows(true) == 1
    if not last_pick:
        reward_panel.show()
    if card:
        # The pick is still flying to the deck button (card_rewards.gd::_launch_pick_flight).
        _track_flight(CardRewards.FLIGHT_TIME)
    # Idea 7: a picked card takes its row away, a Skip leaves the row there, dimmed.
    if is_instance_valid(row):
        if card:
            _claim_row(row)
        else:
            _mark_row_skipped(row)
    if not character_stats or not card:
        return
    print("reward taken")
    character_stats.deck.add_card(card)
    SFXPlayer.play(Global.sfx_click)

# source is the reward row that was clicked; the relic flies from it to the top bar so the
# eye follows it there. Optional so any older/unbound connection still works.
func _on_relic_reward_taken(relic: Relic, source: Control = null) -> void:
    if not relic or not relic_handler:
        return

    # The row is about to fold away under the cursor, so its mouse_exited may never come.
    _relic_hover_id += 1
    _cleanup_relic_tooltips()
    var from_global := RelicHandler.NO_ORIGIN
    if is_instance_valid(source):
        from_global = source.get_global_rect().get_center()
        _claim_row(source)
    relic_handler.add_relic(relic, true, from_global)
    _track_flight(RelicHandler.FLIGHT_TIME + RelicHandler.ARRIVAL_PUNCH_TIME)


# Idea 6: the gold flies to the counter, and the counter counts when it lands.
func on_gold_reward_taken(amount: int, row: Control = null) -> void:
    # Laddered by amount like STS2's three gold sounds (<=30, 31-99, 100+). PLACEHOLDER: one
    # sample, pitched, until there are three.
    var pitch := 1.08
    var volume := -2.0
    if amount >= 100:
        pitch = 0.9
        volume = 2.0
    elif amount > 30:
        pitch = 1.0
        volume = 0.0
    SFXPlayer.play(Global.sfx_gold_pickup, false, pitch, volume)
    # The state is true at once; only the COUNTER waits for the coins (the power-orb rule).
    # run_stats.gold is synced later, in _release_gold_counter: its setter emits gold_changed,
    # which is exactly what starts the counter.
    Global.gold += amount
    var from := get_viewport_rect().get_center()
    if is_instance_valid(row):
        from = (row as RewardButton).custom_icon.get_global_rect().get_center()
        _claim_row(row)
    _gold_counter_pending = true
    var settle := RewardFlow.fly_gold_to_counter(get_tree(), from, amount, func(i: int) -> void: _on_gold_coin_landed(i))
    if settle <= 0.0:
        _release_gold_counter()
    else:
        _track_flight(settle)
        # Backstop: an interrupted flight must never leave the counter stale.
        get_tree().create_timer(1.2).timeout.connect(_release_gold_counter)


func _on_back_button_pressed() -> void:
    if _done:
        return
    if _has_unclaimed_rewards() and not warning_dismissed:
        _show_warning()
    else:
        _exit_battle_rewards()

# Worth a warning: gold or a relic not taken, or a card row never even opened. A card row
# that was opened and skipped is a choice, not something forgotten (STS2 tracks skipped
# rewards the same way), so Continue lets it go quietly.
func _has_unclaimed_rewards() -> bool:
    return _unclaimed_rows(false) > 0

func _show_warning() -> void:
    if warning_panel:
        warning_label.text = UNSEEN_CARDS_WARNING if _only_unseen_cards_left() else UNCLAIMED_WARNING
        warning_panel.show()
        SFXPlayer.play(Global.sfx_click)

# True when everything still worth a warning is a card row nobody opened.
func _only_unseen_cards_left() -> bool:
    var found := false
    for child: Node in rewards.get_children():
        if not (child is RewardButton) or child.has_meta("claimed") or child.has_meta("skipped"):
            continue
        if not child.has_meta("card_row") or child.has_meta("seen"):
            return false
        found = true
    return found

func _exit_battle_rewards() -> void:
    # Once: Continue and the automatic exit (idea 8) can both get here.
    if _leaving:
        return
    _leaving = true
    Events.battle_reward_exited.emit()
    Events.start_map_music.emit()


func _on_confirm_button_pressed() -> void:
    warning_panel.hide()
    warning_dismissed = true
    SFXPlayer.play(Global.sfx_click)


func _on_join_discord_button_pressed() -> void:
    OS.shell_open("https://discord.gg/fah8A2qQx2")


const GG_ENTRANCE_TIME := 0.34
const GG_STATS_REVEAL_DELAY := 0.25

# Settle-in pop for the GG panel, then hand off to the run-stats scoreboard's own
# staggered reveal (same beat structure as the Game Over screen).
func _show_gg_panel() -> void:
    gg_panel.show()
    gg_panel.pivot_offset = gg_panel.size / 2.0
    gg_panel.modulate.a = 0.0
    gg_panel.scale = Vector2(0.93, 0.93)
    var tween := create_tween()
    tween.tween_property(gg_panel, "modulate:a", 1.0, GG_ENTRANCE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(gg_panel, "scale", Vector2.ONE, GG_ENTRANCE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_interval(GG_STATS_REVEAL_DELAY)
    tween.tween_callback(gg_run_stats.animate_in)


# Act-1-complete variant of the GG panel: retitled, act-2 "early preview" notice,
# and the Continue button next to the (always-visible) Discord CTA. The actual act
# switch is armed in run.gd (_on_battle_won) and fires on the next return to the
# map - this button only dismisses the panel, so the boss gold/card rewards
# underneath can still be collected before leaving.
func _setup_act_transition_panel() -> void:
    gg_label_title.text = "Act 1 Complete!"
    gg_label_text.text = """[center][color=#f2a7c3]Well rolled, adventurer![/color] But the dungeon runs deeper — and the dice grow stranger. [color=#f0c040]You will be fully healed upon entering Act 2.[/color]

Act 2 is an [color=#f0c040]early preview[/color]: most of it will be properly reworked for the official launch of Dice Odyssey. [color=#98a7ff]To stay up to date, join the Discord![/color][/center]"""
    continue_act_2_button.show()
    gg_main_menu_button.hide()


func _on_continue_act_2_button_pressed() -> void:
    SFXPlayer.play(Global.sfx_click)
    gg_panel.hide()
    # The run continues past this panel - bring the relic bar + Discord pin back.


func _on_gg_main_menu_button_pressed() -> void:
    # Same recipe as the pause menu's quit: the music autoloads survive the scene
    # change, so without these the run's music would keep looping under the menu.
    # Dip to black before the swap, and let the music play through the dip - it is cut
    # below, at full black, instead of at full brightness.
    await Curtain.cover()
    MusicPlayer.stop()
    SFXPlayer.stop()
    get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# =========================================================================================
# Win -> rewards flow (reward_flow.gd, numbered ideas in its header)
# =========================================================================================

func _apply_reward_flow_backdrop() -> void:
    if over_live_room:
        # Idea 1: the room itself is the backdrop, hero included.
        background.hide()
        background_dimmer.color.a = RewardFlow.OVERLAY_DIM
        # The copied background used to be what swallowed clicks meant for the room below.
        background_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    else:
        # Swap fallback, no room to sit over: same framing as the fight's Sprite2D (native
        # size, from the top-left) instead of keep-aspect-centred, so no 8% zoom-out and no
        # grey strips on the 1373x784 hallway art, and the fight's own grade.
        background.stretch_mode = TextureRect.STRETCH_KEEP
        if RewardFlow.last_bg_material:
            background.material = RewardFlow.last_bg_material
    # Idea 4: the map music comes in under this screen once the jingle has rung out.
    get_tree().create_timer(RewardFlow.MAP_MUSIC_DELAY).timeout.connect(_start_map_music_early)


func _start_map_music_early() -> void:
    if is_inside_tree():
        Events.start_map_music.emit()


func _reward_flow_row_entrance(button: Control, pop_delay: float) -> void:
    var row := button as RewardButton
    if row == null:
        return
    # Idea 5: the coins the last kill dropped fly into the gold row as it pops in.
    if button == _gold_row and not RewardFlow.loot_coins.is_empty():
        var icon := row.custom_icon
        var target := icon.get_global_rect().get_center()
        RewardFlow.fly_loot_to(get_tree(), target, maxf(pop_delay - 0.2, 0.0), func(i: int) -> void: _on_loot_coin_landed(icon, i))
    # Idea 9: every boss offer is Rare (CardRarityDraw's BOSS odds row), so the row says so.
    if button.has_meta("card_row") and reward_context == RewardContext.BOSS:
        _apply_boss_card_row(row)


func _on_loot_coin_landed(icon: Control, i: int) -> void:
    RewardFlow.flash(icon, 1.5)
    RewardFlow.play_tink(i)


func _apply_boss_card_row(row: RewardButton) -> void:
    row.reward_text = "Add a Rare Card"
    var normal := row.get_theme_stylebox("normal") as StyleBoxFlat
    if normal != null:
        var rim := normal.duplicate() as StyleBoxFlat
        rim.border_color = Color(0.96, 0.78, 0.28, 1.0)
        rim.set_border_width_all(3)
        rim.shadow_color = Color(0.96, 0.75, 0.25, 0.35)
        rim.shadow_size = 8
        row.add_theme_stylebox_override("normal", rim)
    var hover := row.get_theme_stylebox("hover") as StyleBoxFlat
    if hover != null:
        var rim_hover := hover.duplicate() as StyleBoxFlat
        rim_hover.set_border_width_all(3)
        rim_hover.shadow_size = 12
        row.add_theme_stylebox_override("hover", rim_hover)
    row.custom_text.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))


func _on_gold_coin_landed(i: int) -> void:
    _release_gold_counter()
    RewardFlow.flash(RewardFlow.gold_counter_icon(get_tree()), 1.45)
    RewardFlow.play_tink(i)


func _release_gold_counter() -> void:
    if not _gold_counter_pending:
        return
    _gold_counter_pending = false
    if run_stats:
        # RunStats.set_gold emits gold_changed itself.
        run_stats.gold = Global.gold
    else:
        Events.gold_changed.emit()


func _claim_row(row: Control) -> void:
    if row.has_meta("claimed"):
        return
    row.set_meta("claimed", true)
    # IGNORE rather than disabled: a disabled Button draws the theme's default disabled box
    # (a pinkish plate) for the length of the fade.
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Idea 6: the row folds away so the rows below slide up instead of snapping.
    var fade := row.create_tween()
    fade.tween_property(row, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    fade.tween_callback(_swap_row_for_spacer.bind(row))
    # The last reward starts the exit right away, while it is still flying (idea 8). Waiting
    # for the fold would leave an empty panel on screen for a moment.
    _check_done_state()


# A container never shrinks a child below its content's minimum size, so the faded row is
# swapped for an empty spacer of the same height, and the SPACER shrinks.
func _swap_row_for_spacer(row: Control) -> void:
    if not is_instance_valid(row):
        return
    var parent := row.get_parent()
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0.0, row.size.y)
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(spacer)
    parent.move_child(spacer, row.get_index())
    parent.remove_child(row)
    row.queue_free()
    var shrink := spacer.create_tween()
    shrink.tween_property(spacer, "custom_minimum_size:y", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    shrink.tween_callback(spacer.queue_free)
    shrink.tween_callback(_check_done_state)


func _mark_row_skipped(row: Control) -> void:
    row.set_meta("skipped", true)
    row.modulate = Color(0.6, 0.6, 0.6, 1.0)
    _check_done_state()


# Rows still worth a warning: not claimed, and (unless include_skipped) not skipped.
func _unclaimed_rows(include_skipped: bool) -> int:
    var n := 0
    for child: Node in rewards.get_children():
        if not (child is RewardButton) or child.has_meta("claimed"):
            continue
        if child.has_meta("skipped") and not include_skipped:
            continue
        n += 1
    return n


# Idea 8: nothing left to take, so the screen leaves on its own (Julien, 2026-09-24: "we
# don't need the continue button to stay; if you picked every reward, we can move on").
# The panel fades and the room comes back up (STS2: window fades 0.25s, backstop hides),
# then it leaves the way Continue does, once nothing is still flying. Rows that were only
# skipped keep the screen open, with Continue pulsing.
func _check_done_state() -> void:
    if _done:
        return
    if _unclaimed_rows(true) == 0:
        _enter_done_state()
    elif _unclaimed_rows(false) == 0:
        # Only skipped rows left: nothing to warn about, so point at Continue.
        RewardFlow.attach_pulse_ring(back_button)


func _enter_done_state() -> void:
    _done = true
    # Continue has nothing left to do: it fades with the panel and stops taking clicks.
    # IGNORE rather than disabled, for the same pinkish-box reason as a claimed row.
    back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var dim_target := 0.0 if over_live_room else 0.6
    var t := create_tween().set_parallel(true)
    t.tween_property(title_label, "modulate:a", 0.0, DONE_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    t.tween_property(reward_container, "modulate:a", 0.0, DONE_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    t.tween_property(back_button, "modulate:a", 0.0, DONE_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    t.tween_property(background_dimmer, "modulate:a", dim_target, DONE_ROOM_UP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # The room coming back up is waited on like one more flight.
    _track_flight(DONE_ROOM_UP_TIME)


# Game-time timers, not wall-clock: they stay in step with the tweens they wait for. And NOT
# process_always (create_timer's default): opening the map or the pause menu right after the
# last reward pauses the tree, and the exit must wait for it instead of firing behind it.
func _track_flight(seconds: float) -> void:
    _flights_in_air += 1
    get_tree().create_timer(seconds + LANDING_BEAT, false).timeout.connect(_on_flight_landed)


func _on_flight_landed() -> void:
    _flights_in_air -= 1
    if _done and _flights_in_air <= 0:
        _exit_battle_rewards()
