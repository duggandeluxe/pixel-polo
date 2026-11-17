class_name CardsData
extends RefCounted
## Event cards (between games). Every choice is a
## trade-off; effects are Career.apply_effects() entries (see LockerData). "{name}" in a card's
## text is the player it's about, picked by its `who`: any, center, keeper, shooter, freshman,
## senior. A card with `once` shows at most once per career.

## (All weekly cards were removed; the list is kept empty so no card ever shows.)
const CARDS := []
