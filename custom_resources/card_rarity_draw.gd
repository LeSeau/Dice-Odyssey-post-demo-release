class_name CardRarityDraw
extends RefCounted

# Shared by battle_reward.gd (hallway/elite/boss card offers) and card_shop.gd (guaranteed
# per-tier shop slots) - keeps "how do we pick a card of a given tier" in one place instead of
# duplicating the owned-Rare dedup logic in both gameplay files.


# Picks a random card of `tier` from `pool`. With only 5 Rares in the whole game, offering one
# the player already owns (e.g. a repeat on the act-2 boss screen after already taking it on
# the act-1 boss screen) reads as a dud slot rather than a jackpot - so for RARE specifically,
# prefer a card not already in `owned` and only fall back to the full tier pool once every Rare
# is already owned. Commons/Uncommons don't get this treatment: owning duplicates of those is
# normal deck-building, not a wasted "rare moment".
static func pick_card(pool: Array[Card], tier: Card.RarityTier, owned: Array[Card] = []) -> Card:
    var candidates := pool.filter(func(c: Card): return c.rarity_tier == tier)
    if candidates.is_empty():
        return null

    if tier == Card.RarityTier.RARE and not owned.is_empty():
        var owned_ids: Array = owned.map(func(c: Card): return c.id)
        var unowned := candidates.filter(func(c: Card): return not owned_ids.has(c.id))
        if not unowned.is_empty():
            candidates = unowned

    candidates.shuffle()
    return candidates.pick_random()
