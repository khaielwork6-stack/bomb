--!strict
-- Per-map gameplay data (D-02). Geometry comes from the built maps' Zones (script contract);
-- these are gameplay-only overlays placed at runtime inside <Map>.Gameplay.
-- Socket offsets are fractions of the field (x along length, z along width) so they adapt to the built size.

local SOCKETS_4x4 = {}
for _, fx in ipairs({ -0.32, -0.11, 0.11, 0.32 }) do
	for _, fz in ipairs({ -0.30, -0.10, 0.10, 0.30 }) do
		table.insert(SOCKETS_4x4, Vector2.new(fx, fz))
	end
end

return {
	-- P3 (2026-10-17): the Fireworks Yard is the launch map (builders/MapYard); the Meadow stays parked as a fallback.
	Order = { "Yard", "Meadow", "Quarry" }, -- the Quarry is map 2 (rotation / the map vote: partner request #1)
	List = {
		Yard = {
			displayName = "The Fireworks Yard",
			hazards = {},
			sockets = SOCKETS_4x4,
			thumbnail = "rbxassetid://83978149323296", -- the vote card (an overview of the toy restyle, art/out/MapThumbs)
		},
		-- 2026-10-18 map 2 (builders/MapQuarry, docs/maps/QUARRY_BRIEF.md): the sandstone quarry. Same field frame and
		-- hooks as the Yard (HazardLanes = its mine rails, FuseCords in timber troughs, Cover = mine carts + dynamite).
		Quarry = {
			displayName = "The Quarry",
			hazards = {},
			sockets = SOCKETS_4x4,
			thumbnail = "", -- the vote card: an overview shot once the map is dressed
		},
		-- 2026-10-09 v2 (builders/MapMeadow): the home farm stadium. Its round hay bales roll (Templates.Roller), its
		-- square hay bales rise (Templates.BlockTemplate), the sheep stampede stays.
		Meadow = {
			displayName = "The Meadow",
			hazards = { "ROLLING_BOULDERS", "SPRINKLERS", "STAMPEDE" },
			sockets = SOCKETS_4x4,
			stampedeCritter = "Sheep",
			sprinklers = { Vector2.new(-0.25, 0.45), Vector2.new(0, -0.45), Vector2.new(0.25, 0.45) },
			thumbnail = "rbxassetid://81681930726624", -- the vote card (an overview shot of v2)
			lighting = "MeadowDay",
			night = "MeadowNight",
			standSides = { -1 },
			look = {
				socket = { -- wooden trapdoors with a warm glowing rim
					color = Color3.fromRGB(128, 86, 52),
					material = Enum.Material.WoodPlanks,
					rim = Color3.fromRGB(255, 210, 90),
					rimMaterial = Enum.Material.Neon,
				},
				stands = {
					bench = Color3.fromRGB(196, 140, 92),
					riser = Color3.fromRGB(150, 98, 58),
					rail = Color3.fromRGB(246, 244, 236),
				},
			},
		},
	},
}
