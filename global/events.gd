extends Node

# Card-related events
signal card_drag_started(card_ui: CardUI)
signal card_drag_ended(card_ui: CardUI)
signal card_aim_started(card_ui: CardUI)
signal card_aim_ended(card_ui: CardUI)
# Emitted whenever the enemy under the aiming reticle changes (card_target_selector.gd).
# The aiming CardUI refreshes its own damage preview directly, but a card played from the
# red socket is HIDDEN while aiming, so dice.gd's socket display has to refresh off this.
signal card_aim_target_changed(card_ui: CardUI)
signal card_played(card: Card)
#signal card_tooltip_requested(card: Card)
#signal tooltip_hide_requested
signal card_charged(card_ui)
signal reset_charged_card
signal block_reset
signal add_block(amount)
signal fan_hand_requested
signal draw_card(amount)
signal scout_effect(amount)
signal refuel_happened(amount)
# Thrown-dice cards (Meteor, Fastball, Cursed Toss, Pixie Volley, Dice Avalanche, All In):
# visual-only request to fly dice from `origin` to their targets, rolling in the air and
# landing on each throw's final face. Each entry: {"type": String, "value": int,
# "target": Node, optional "thud": bool} - "thud" marks a die whose impact carries no
# damage sound of its own (All In's consumed dice: their total lands once at the end), so
# the visual side plays a landing clack for it. The DAMAGE is scheduled separately by the
# card via Card._land_thrown_die() using Global.DICE_THROW_FLIGHT_TIME and the shared
# Global.dice_throw_volley_stagger() spacing, so each hit lands as its die slams.
signal dice_thrown(throws: Array, origin: Vector2)
# One thrown/conjured die finished resolving at its landing (emitted by
# Global.report_thrown_die_landed, once per die). Deliberately separate from dice_rolled:
# dice_interface decrements your active pool on dice_rolled and dozens of card scripts arm
# "your next roll" effects on it - thrown dice must never touch those.
#
# ⚠️ A THROW IS NOT A ROLL (Julien, 2026-08-29). This signal means "a thrown die resolved",
# nothing more. It does NOT mean a die was rolled, and it must never be used to feed a
# roll counter or a roll-triggered relic/status/card. Between 2026-07-23 and 2026-08-29
# eighteen listeners opted into it on the opposite ruling (Crown, Metronome, Sixth Gear,
# Hunting Bow, Needle Die, Snake Eyes Charm, Underdog Ring, The One, Giant's Signet,
# House Money, Jackpot Pin, Consolation Chip, Prismatic Lens, Effigy, Ruptured, Hardened
# Grip, Greedy, card_ui's description refresh) - all of them were disconnected.
#
# It is kept, with zero listeners, as the hook for content that is deliberately ABOUT
# throwing (the way Trebuchet's flat per-throw bonus is). If you connect something here,
# it must be a throw payoff, not a roll payoff.
signal dice_thrown_landed(dice_type: String, value: int)
# Double or Nothing: visual-only coin toss from `origin`. The card resolves the outcome after
# Global.COIN_FLIP_TIME on its own timer; this just animates the flip + reveal.
# target: the enemy the coin is tossed above (null = fall back to the card release
# point). Must be emitted with all three args - a 2-arg emit silently no-ops the
# listener at emit time in Godot 4.
signal coin_flip(heads: bool, origin: Vector2, target: Node)
# Emitted by player_handler.reshuffle_deck_from_discard() only when cards ACTUALLY moved
# (never at battle start, where the draw pile is built full and the guard returns early).
# Purely visual for now: battle_ui.gd flies mini card-backs from the discard pile button to
# the draw pile button so the reshuffle stops being an invisible counter swap.
signal deck_reshuffled(card_count: int)

# Player-related events
signal player_hand_drawn
signal player_hand_discarded
signal player_turn_started
signal player_turn_ended
signal player_hit
# An incoming hit was absorbed ENTIRELY by Block - no HP lost. Distinct from player_hit,
# which only fires when health actually drops, so neither can stand in for the other.
# `attacker` is the enemy taking its turn, or null if the damage had no enemy source.
signal player_fully_blocked(attacker)
signal player_died
signal gold_changed
signal hp_changed
signal update_dice_top_bar
signal event_damage(amount)

# Enemy-related events
signal enemy_action_completed(enemy: Enemy)
signal enemy_turn_ended
signal enemy_died(enemy: Enemy)

# Battle-related events
signal battle_started
signal battle_over_screen_requested(text: String, type: BattleOverPanel.Type)
# Emitted by the full-screen end panels (Game Over, Act 1 Complete, Dungeon Conquered) so
# run.gd can hide the HUD chrome that floats above every view (RelicBar + the Discord pin,
# both on CanvasLayers) - with 5+ relics the bar renders straight over the panel title.
# false = end screen showing, hide them; true = restore (Act 1 Complete's Continue button,
# the one end-panel exit where the run keeps going).
signal end_screen_hud_visibility(hud_visible: bool)
signal battle_won
signal show_reward
signal force_end_turn
signal stop_map_music
signal stop_battle_music
signal start_map_music

# Map-related events
signal map_exited(room: Room)
signal shop_exited
signal campfire_exited
signal battle_reward_exited
signal treasure_room_exited(found_relic: Relic)
signal event_exited

signal shop_relic_bought (relic: Relic, gold_cost: int)
signal shop_card_bought(card: Card, gold_cost: int)

#Dice-related events
signal dice_rolled(active_dice, roll_value)
signal active_dice_changed(active_dice)
signal dice_amount_changed(active_dice, current_amount, max_amount)
signal dice_roll_reset
signal red_dice_rolled
signal change_current_power
signal next_roll_determined
signal next_roll_randomized
signal weak_effect_consumed
signal check_lucky_status
signal check_unlucky_status
signal check_weak_status
signal check_infused_status
signal check_canalize_status
signal check_ink_status
signal check_chaos_status
signal discard_random_card
signal put_ink_on_dice
signal remove_ink_from_dice
signal check_if_losing_strength
signal dice_bought(dice_type)
signal resize_dice_interface
signal dice_price_changed
# DEPRECATED (2026-08-14): argless predecessor of dice_charged below. Kept DECLARED so a
# stray unmigrated emitter no-ops instead of crashing, but nothing listens to it anymore -
# emit dice_charged with the real type/count instead.
signal charge_dice_animation
# Every "gain N dice of TYPE mid-fight" source (Charge cards, relics, statuses, Sigil/Gnome
# triggers) emits this. Drives the card->slot delivery flight (dice_interface.gd) and the
# active-die absorb ceremony (dice.gd, only when the charged type IS the active type).
# Multi-type sources (Experiment, War Ritual...) emit once PER die so each delivery flies in
# its own type's color - that's what makes a random charge readable.
signal dice_charged(dice_type: String, count: int)
# Presentation-only companion to dice_charged: emitted by the DiceInterface exactly ONCE
# per volley, at the moment the volley's LAST delivered die lands in its slot (or right
# away when no flight is possible - no ui_layer - and via a failsafe timer if an arrival
# callback is ever lost; see dice_interface.gd). dice.gd keys the big die's entire charge
# response (gust + aura flash + absorb ceremony) on THIS signal, never on dice_charged:
# the pulse is a landing receipt, not a launch announcement (Julien, 2026-08-28). Carries
# the volley's FULL count, not the icon-capped visual count.
signal dice_charge_delivered(dice_type: String, count: int)
signal enemy_strength_changed
signal display_next_roll_modifier
signal card_removed(card)
signal open_deck_view
signal open_deck_view_for_upgrade
signal card_upgrade_requested(card)

signal check_if_can_purchase_dice

signal clear_socket


signal temporary_dice_added(dice_type: String)
signal add_card_to_hand_requested(card: Card)
# Same shape, different destination: drops a card straight into the DISCARD pile, so it is met
# on the next shuffle rather than the next draw. Used by the Slanderer to plant junk.
# Always pass a duplicate() - two CardUI nodes sharing one Card instance_id both resolve as
# "the" played card at once (see the note in calculations.gd).
signal add_card_to_discard_requested(card: Card)
signal show_map_requested
# Closing the floating dice shop panel. Deliberately NOT shop_exited/show_map_requested:
# those mean "this room is over, go back to the map", which frees the current view - the
# dice shop only ever floats on top of a room, so it must not navigate anywhere.
signal dice_shop_closed
# Emitted by the act-2 dice infusion screen (scenes/dice_infusion/) once the pick is
# locked in and its ceremony has played - run.gd answers by entering act 2 + showing
# the new map.
signal dice_infusion_completed
# Emitted by the run-start dice loadout picker (scenes/dice_loadout) once the chosen
# set's dice amounts are written into Global and its ceremony has played - run.gd
# answers by announcing act 1 and showing the map. Run #2+ only (run.gd::_start_run).
signal dice_loadout_completed
signal card_type_played(card_type)

signal show_warning_message

signal show_reward_with_relic(relic: Relic)
# Same reward screen, but also drops a claimable gold pill next to the relic -
# for events like event_russian_dice.gd where gold was banked separately from
# the relic and needs to show up (and be claimed) exactly once, not be
# silently added to Global.gold before the screen even opens.
signal show_reward_with_relic_and_gold(relic: Relic, gold_amount: int)

signal update_roll_history_ui
signal hover_playable_cards
