class_name CardRarityDraw
extends RefCounted

# Shared by battle_reward.gd (hallway/elite/boss card offers) and card_shop.gd (merchant
# slots) - keeps both "which rarity does this slot roll" and "how do we pick a card of a
# given tier" in one place instead of duplicating either in both gameplay files.
#
# ---------------------------------------------------------------------------------------
# The rarity model is a direct port of Slay the Spire 2's, mined from its decompiled
# Core/Odds/CardRarityOdds.cs + Core/Factories/CardFactory.cs (2026-08-28). Read that file
# before retuning anything here - the shape matters more than the numbers:
#
#   * ONE float per card. Rare if x < base_rare[source] + offset, else Uncommon if
#     x < base_uncommon[source] + that, else Common.
#   * Uncommon is a FIXED slice per source. The pity offset only ever eats into Common's
#     share - it never trades against Uncommon.
#   * The offset starts NEGATIVE, so the opening cards of a run literally cannot be Rare.
#   * It advances per CARD and snaps back to the floor the instant a Rare is rolled.
#
# That last point is the whole reason STS2 screens don't show two Rares side by side: slot 1
# coming up Rare drops the offset back under water before slot 2 is rolled. Our previous
# model advanced pity once per SCREEN, so all three slots shared one inflated weight and
# rares clustered - measured 12% of elite screens showing 2+ rares, vs 2.1% here.
# ---------------------------------------------------------------------------------------

enum Source {NORMAL, ELITE, BOSS, SHOP}

# STS2's CardRarityOdds.GetBaseOdds, ascension-0 values. Common is the remainder and is
# never read, so it isn't stored: NORMAL .60/.37/.03, ELITE .50/.40/.10, BOSS 0/0/1,
# SHOP .54/.37/.09.
const BASE_UNCOMMON_ODDS := {
    Source.NORMAL: 0.37,
    Source.ELITE: 0.40,
    Source.BOSS: 0.0,
    Source.SHOP: 0.37,
}
const BASE_RARE_ODDS := {
    Source.NORMAL: 0.03,
    Source.ELITE: 0.10,
    Source.BOSS: 1.0,
    Source.SHOP: 0.09,
}


# Mirrors CardRarityOdds.RollWithoutChangingFutureOdds - rolling does NOT advance the
# offset. Callers that should move it (encounter rewards) pass the result to
# advance_offset(); callers that shouldn't (the shop) simply don't, which is exactly how
# the reference splits Roll() from RollWithoutChangingFutureOdds().
#
# BOSS deliberately rolls with the offset forced to 0, matching the reference's
# `(type == BossEncounter) ? 0f : CurrentValue`. Its rare odds are 1.0 so it cannot
# currently matter, but keeping the shape means a future non-1.0 boss row behaves like
# STS2's would instead of silently inheriting run pity.
static func roll_rarity(source: Source, offset: float) -> Card.RarityTier:
    var uncommon_base: float = BASE_UNCOMMON_ODDS[source]
    var rare_base: float = BASE_RARE_ODDS[source]
    var applied_offset := 0.0 if source == Source.BOSS else offset
    var rare_chance := rare_base + applied_offset

    var x := randf()
    if x < rare_chance:
        return Card.RarityTier.RARE
    if x < uncommon_base + rare_chance:
        return Card.RarityTier.UNCOMMON
    return Card.RarityTier.COMMON


# Mirrors the tail of CardRarityOdds.Roll(): reset to the floor on a Rare, otherwise creep
# up by one growth step, clamped at the cap. Call this once per card actually rolled for an
# encounter reward - never for shop slots.
static func advance_offset(offset: float, rolled: Card.RarityTier) -> float:
    if rolled == Card.RarityTier.RARE:
        return RunStats.RARE_OFFSET_FLOOR
    return minf(offset + RunStats.RARE_OFFSET_GROWTH, RunStats.RARE_OFFSET_CAP)


# Picks a random card of `tier` from `pool`. With a thin Rare pool, offering one the player
# already owns (e.g. a repeat on the act-2 boss screen after already taking it on the act-1
# boss screen) reads as a dud slot rather than a jackpot - so for RARE specifically, prefer a
# card not already in `owned` and only fall back to the full tier pool once every Rare is
# already owned. Commons/Uncommons don't get this treatment: owning duplicates of those is
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
