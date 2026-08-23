class_name RelicPool
extends Resource

# Rarity odds, matching the card system's shape (see BattleReward's card weights) and Slay
# the Spire's relic split. Tuned as WEIGHTS rather than percentages so a pool that has run
# out of, say, Rares still draws sensibly instead of returning null.
const RARITY_WEIGHTS := {
	Relic.RarityTier.COMMON: 50.0,
	Relic.RarityTier.UNCOMMON: 33.0,
	Relic.RarityTier.RARE: 17.0,
}

@export var pool: Array[Relic] = []


# Treasure / elite / event draw. Shop-only relics are filtered OUT here, which is the whole
# point of the flag: availability is enforced by the data rather than by remembering to keep
# two pool files in sync (they used to be maintained by hand and could silently drift).
func get_random_relic(character_stats: CharacterStats, relic_handler: RelicHandler, exclude: Array[Relic] = []) -> Relic:
	return _weighted_pick(_available(character_stats, relic_handler, exclude, false))


# Shop draw: the same weighting, but shop-exclusive relics ARE included - this is the only
# place they can appear.
func get_random_shop_relic(character_stats: CharacterStats, relic_handler: RelicHandler, exclude: Array[Relic] = []) -> Relic:
	return _weighted_pick(_available(character_stats, relic_handler, exclude, true))


func _available(character_stats: CharacterStats, relic_handler: RelicHandler,
		exclude: Array[Relic], include_shop_only: bool) -> Array[Relic]:
	return pool.filter(
		func(relic: Relic):
			if relic == null:
				return false
			if relic.shop_only and not include_shop_only:
				return false
			var can_appear := relic.can_appear_as_reward(character_stats)
			var already_have := relic_handler.has_relic(relic.id)
			var already_excluded := exclude.has(relic)
			return can_appear and not already_have and not already_excluded
	)


# Picks the TIER first, then a relic uniformly inside it.
#
# ⚠️ The obvious alternative - give every relic its tier's weight and pick across the whole
# list - looks equivalent and is not: it makes the odds depend on how many relics each tier
# happens to contain. With the current roster (15/27/6) that turned a nominal 50/33/17 into
# roughly 43/51/6, so drafting more Uncommons would have quietly made Uncommons *more*
# likely and Rares rarer. Choosing the tier first keeps the advertised odds stable no matter
# how the roster grows.
#
# Tiers with nothing left to offer are dropped and the remaining weights renormalise, so an
# exhausted tier (every Rare already owned) degrades to the other tiers instead of returning
# null and silently dropping the reward.
func _weighted_pick(available: Array[Relic]) -> Relic:
	if available.is_empty():
		return null

	var by_tier := {}
	for relic: Relic in available:
		if not by_tier.has(relic.rarity_tier):
			by_tier[relic.rarity_tier] = [] as Array[Relic]
		by_tier[relic.rarity_tier].append(relic)

	var total := 0.0
	for tier in by_tier:
		total += RARITY_WEIGHTS.get(tier, 1.0)

	var roll := randf() * total
	for tier in by_tier:
		roll -= RARITY_WEIGHTS.get(tier, 1.0)
		if roll <= 0.0:
			var bucket: Array[Relic] = by_tier[tier]
			return bucket.pick_random()

	# Float drift only - the loop above resolves in every practical case.
	return available[available.size() - 1]
