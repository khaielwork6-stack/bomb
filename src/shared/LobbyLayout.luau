--!strict
-- Lobby layout (2026-10-06/07, the user's brief): the partner's lobby is re-arranged at runtime (builders/ untouched)
-- around the spawn, like seats around a table:
--   • ≈35 % more lawn: the island grows EXTRA_X studs towards +X (−X is the Dash Course bridge) and EXTRA_BACK at
--     the back (+Z, the terrace); the decor along those edges moves out with them, props keep their size;
--   • looking in from the spawn (+Z is "back", +X is "left"): the rewards out on the left (2026-10-07: pushed back
--     towards the +X edge, away from the centre; shop, like gift, invite NPC,
--     spin wheel at the back-left), the crates on the right with the lane to the Dash Course bridge between them,
--     the event board back-right, the podium straight ahead and the leaderboards behind it on the terrace;
--   • every station turned to face CENTRE (the spawn); prompt rings never overlap (≥ 18 studs apart); the dock
--     path, the bridge lane and the terrace step stay clear.
-- Positions are ground points; stations stand on the lawn (y = FLOOR).

local LobbyLayout = {}

-- The whole lobby and the Dash Course stand this much higher than built (2026-10-08, the user: "higher, so players
-- can easily look down on the match"). Every height below is as built; the lift is added at the bottom of this file
-- (and DashCourseLayout's), and LobbyArranger raises the place's lobby by the same amount at server start (the
-- island's cliff and the dock's posts reach back down to the water). 0 = as built.
LobbyLayout.LIFT = 12

LobbyLayout.CENTRE = Vector3.new(0, 10, 105) -- the spawn (on the orange pad)
LobbyLayout.FLOOR = 10
LobbyLayout.EXTRA_X = 24
LobbyLayout.EXTRA_BACK = 14

LobbyLayout.Stations = {
	Shop = Vector3.new(57, 10, 108),
	LikeReward = Vector3.new(50, 10, 90),
	SpinWheel = Vector3.new(52, 10, 125),
	AuroraCrate = Vector3.new(-34, 10, 91),
	SolarCrate = Vector3.new(-34, 10, 121),
	EventBoard = Vector3.new(-33, 10, 135),
	Podium = Vector3.new(0, 10, 130),
}
-- The rewards end of the back terrace (2026-10-07, the user's pick: the open space behind the wheel; the terrace top
-- is y = 12): the invite NPC and the floating weapon showcase (ShowcaseController), ≥ 18 studs apart.
LobbyLayout.InviteNPC = Vector3.new(44, 12, 153)
LobbyLayout.Showcase = Vector3.new(63, 12, 155)
LobbyLayout.ShowcaseItem = "Tool.Thunder" -- Legendary, sold in the Shop
-- The supporter shrine (2026-10-07): the free Riftblade in its violet rift, on the terrace front right of the
-- leaderboards: in clear view from the spawn (past the event board's edge) and ≥ 18 studs from its prompt.
LobbyLayout.Supporter = Vector3.new(-26, 12, 152)
-- The shop stall, a little smaller than built, standing on the lawn (2026-10-08, the user: the floating, bobbing
-- 0.55 stall looked out of place; it stands still on the ground now).
LobbyLayout.SHOP_SCALE = 0.75
LobbyLayout.SHOP_FLOAT = 0
LobbyLayout.LEADERBOARD_BACK = 9 -- the board row moves this far further back on the (deeper) terrace
-- Decor moved to fixed spots (name, where it stood → where it goes; no `to` = removed), so nothing ends up on a
-- path, on the spawn pad or against another prop.
local decorMoves: { { name: string, from: Vector3, to: Vector3? } } = {
	{ name = "Flowers", from = Vector3.new(-1, 0, 108) }, -- the flower bed on top of the spawn pad
	{ name = "Tree", from = Vector3.new(25, 0, 135), to = Vector3.new(66, 0, 88) },
	{ name = "Flowers", from = Vector3.new(25, 0, 136), to = Vector3.new(72, 0, 98) },
}
LobbyLayout.DecorMoves = decorMoves

-- Apply the lift to every height above (the decor moves are ground-plane only).
do
	local up = Vector3.new(0, LobbyLayout.LIFT, 0)
	LobbyLayout.CENTRE += up
	LobbyLayout.FLOOR += LobbyLayout.LIFT
	for name, pos in pairs(LobbyLayout.Stations) do
		LobbyLayout.Stations[name] = pos + up
	end
	LobbyLayout.InviteNPC += up
	LobbyLayout.Showcase += up
	LobbyLayout.Supporter += up
end

-- A CFrame at `pos` looking at the centre (level).
function LobbyLayout.facing(pos: Vector3): CFrame
	local look = Vector3.new(LobbyLayout.CENTRE.X, pos.Y, LobbyLayout.CENTRE.Z)
	return CFrame.lookAt(pos, look)
end

return LobbyLayout
