extends Node

# Card-related events
signal card_drag_started(card_ui: CardUI)
signal card_drag_ended(card_ui: CardUI)
signal card_aim_started(card_ui: CardUI)
signal card_aim_ended(card_ui: CardUI)
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

# Player-related events
signal player_hand_drawn
signal player_hand_discarded
signal player_turn_started
signal player_turn_ended
signal player_hit
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
signal charge_dice_animation
signal enemy_strength_changed
signal display_next_roll_modifier
signal card_removed(card)
signal open_deck_view

signal check_if_can_purchase_dice

signal clear_socket


signal temporary_dice_added(dice_type: String)
signal add_card_to_hand_requested(card: Card)
signal show_map_requested
signal card_type_played(card_type)

signal tutorial_step_requested(step)
signal show_warning_message

signal show_reward_with_relic(relic: Relic)

signal update_roll_history_ui
signal hover_playable_cards
