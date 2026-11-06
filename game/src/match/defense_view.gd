class_name DefenseView
## Your defence on screen. The AI plays your field defenders; you're the keeper, so he wears
## your ring and the arrow all their possession.

## Under the bodies: your keeper's ring.
static func draw_under(ci: CanvasItem, v: PoolView, p: Play, _t: float) -> void:
	if not p.over:
		PoolArt.draw_ring(ci, v, p.keeper, UI.ACCENT)

## Over the bodies: the arrow over your keeper (not while he's diving: the dive is the picture).
static func draw_over(ci: CanvasItem, v: PoolView, p: Play, _duel: KeeperDuel, t: float) -> void:
	if not p.over and p.keeper.pose == null:
		PoolArt.draw_holder_marker(ci, v, p.keeper, t)
