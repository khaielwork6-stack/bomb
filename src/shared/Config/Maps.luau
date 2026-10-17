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
	Order = { "Meadow" }, -- P0: the temporary map only (GDD §23.1); the Fireworks Yard replaces it in P3
	List = {
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
		Blossom = {
			displayName = "Blossom Court",
			hazards = { "CRUMBLE", "CONVEYORS", "ROLLING_BARRELS", "STAMPEDE" },
			sockets = SOCKETS_4x4,
			stampedeCritter = "Deer",
			conveyors = { -0.2, 0.2 }, -- x fractions of lateral strips
		},
		-- 2026-10-09 grey box (builders/MapShip): the galleon's deck. Hazards: powder kegs rolling across, two
		-- soapy swabbing strips (conveyors), rotten planks (crumble), a stampede (crabs once the art exists; the
		-- placeholder critter until then).
		Ship = {
			displayName = "Skull's Revenge",
			hazards = { "ROLLING_BARRELS", "CONVEYORS", "CRUMBLE", "STAMPEDE" },
			sockets = SOCKETS_4x4,
			stampedeCritter = "Sheep",
			conveyors = { -0.2, 0.2 },
			thumbnail = "rbxassetid://99542382751524", -- the map vote card (an in-game shot of the deck)
			lighting = "GoldenHour", -- LightingController preset under the theme / modifier layers
			standSides = { -1 }, -- the crowd sits in the rigging on the far side; the lobby's side stays open
		},
		-- 2026-10-09: the four new arenas (builders/MapTemple, MapMuseum, MapFactory, MapToy), each with its own
		-- blocks / roller / stampede critter (Templates), hazard colours (look), day lighting and Ghost Hunt night.
		Temple = {
			displayName = "Temple of the Jade Jaguar",
			hazards = { "ROLLING_BOULDERS", "CONVEYORS", "STAMPEDE", "CRUMBLE" },
			sockets = SOCKETS_4x4,
			stampedeCritter = "Sheep", -- the map's monkey (Templates.Critter) replaces it
			conveyors = { -0.2, 0.2 },
			thumbnail = "rbxassetid://118715886790694", -- the vote card (an overview shot)
			lighting = "JungleMorning",
			night = "JungleNight",
			standSides = { -1 },
			look = {
				socket = {
					color = Color3.fromRGB(150, 110, 68),
					material = Enum.Material.Slate,
					grate = false,
					rim = Color3.fromRGB(60, 230, 200),
					rimMaterial = Enum.Material.Neon,
				},
				conveyor = { -- the aqueduct channels: crystal water, foam ripples
					base = Color3.fromRGB(60, 170, 210),
					baseMaterial = Enum.Material.Glass,
					baseTransparency = 0.2,
					slat = { Color3.fromRGB(150, 222, 240), Color3.fromRGB(110, 200, 230) },
					slatMaterial = Enum.Material.SmoothPlastic,
					arrow = Color3.fromRGB(235, 255, 255),
				},
				crumble = { color = Color3.fromRGB(214, 168, 104), material = Enum.Material.Slate },
				stands = {
					bench = Color3.fromRGB(206, 164, 108),
					riser = Color3.fromRGB(150, 110, 68),
					rail = Color3.fromRGB(110, 76, 44),
				},
			},
		},
		Museum = {
			displayName = "The Grand Museum",
			hazards = { "ROLLING_BOULDERS", "CONVEYORS", "STAMPEDE", "SPRINKLERS" },
			sockets = SOCKETS_4x4,
			stampedeCritter = "Sheep", -- the map's baby dino replaces it
			conveyors = { -0.2, 0.2 },
			sprinklers = { Vector2.new(-0.25, 0.45), Vector2.new(0, -0.45), Vector2.new(0.25, 0.45) },
			thumbnail = "rbxassetid://75686803682644", -- the vote card (an overview shot)
			lighting = "MuseumGala",
			night = "MuseumHaunted",
			standSides = { -1 },
			look = {
				socket = {
					color = Color3.fromRGB(52, 50, 58),
					material = Enum.Material.Slate,
					grate = false,
					rim = Color3.fromRGB(255, 200, 90),
					rimMaterial = Enum.Material.Neon,
				},
				conveyor = { -- exhibit walkways: dark rubber, brass slats, gold arrows
					base = Color3.fromRGB(46, 44, 52),
					baseMaterial = Enum.Material.SmoothPlastic,
					baseTransparency = 0,
					slat = { Color3.fromRGB(90, 86, 98), Color3.fromRGB(70, 66, 78) },
					slatMaterial = Enum.Material.Metal,
					arrow = Color3.fromRGB(255, 200, 90),
				},
				stands = {
					bench = Color3.fromRGB(242, 234, 222),
					riser = Color3.fromRGB(176, 30, 44),
					rail = Color3.fromRGB(240, 190, 70),
				},
			},
		},
		Factory = {
			displayName = "Sugar Rush Factory",
			hazards = { "ROLLING_BOULDERS", "CONVEYORS", "STAMPEDE", "SPRINKLERS" },
			sockets = SOCKETS_4x4,
			stampedeCritter = "Sheep", -- the map's gummy bear replaces it
			conveyors = { -0.2, 0.2 },
			sprinklers = { Vector2.new(-0.25, 0.45), Vector2.new(0, -0.45), Vector2.new(0.25, 0.45) },
			thumbnail = "rbxassetid://126772526358316", -- the vote card (an overview shot)
			lighting = "CandyBright",
			night = "CandyNight",
			standSides = { -1 },
			look = {
				blockDyes = { -- the wafer blocks' foil label bands
					Color3.fromRGB(246, 120, 170),
					Color3.fromRGB(90, 190, 240),
					Color3.fromRGB(250, 200, 60),
					Color3.fromRGB(130, 210, 110),
					Color3.fromRGB(186, 130, 236),
				},
				socket = {
					color = Color3.fromRGB(110, 114, 126),
					material = Enum.Material.Metal,
					grate = false,
					rim = Color3.fromRGB(255, 90, 170),
					rimMaterial = Enum.Material.Neon,
				},
				conveyor = { -- candy belts: chocolate, pink and white slats
					base = Color3.fromRGB(92, 52, 34),
					baseMaterial = Enum.Material.SmoothPlastic,
					baseTransparency = 0,
					slat = { Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 240, 246) },
					slatMaterial = Enum.Material.SmoothPlastic,
					arrow = Color3.fromRGB(255, 255, 255),
				},
				spray = { Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 110, 170) }, -- frosting
				stands = {
					bench = Color3.fromRGB(255, 196, 220),
					riser = Color3.fromRGB(110, 60, 36),
					rail = Color3.fromRGB(240, 190, 70),
				},
			},
		},
		Toy = {
			displayName = "The Toy Box",
			hazards = { "ROLLING_BOULDERS", "CONVEYORS", "STAMPEDE", "CRUMBLE" },
			sockets = SOCKETS_4x4,
			stampedeCritter = "Sheep", -- the map's toy soldier replaces it
			conveyors = { -0.2, 0.2 },
			thumbnail = "rbxassetid://74670287437798", -- the vote card (an overview shot)
			lighting = "ToyAfternoon",
			night = "ToyNight",
			standSides = { -1 },
			look = {
				socket = {
					color = Color3.fromRGB(70, 64, 60),
					material = Enum.Material.Fabric,
					grate = false,
					rim = Color3.fromRGB(255, 214, 70),
					rimMaterial = Enum.Material.Neon,
				},
				conveyor = { -- toy-train track: dark wood, light ties
					base = Color3.fromRGB(120, 84, 52),
					baseMaterial = Enum.Material.WoodPlanks,
					baseTransparency = 0,
					slat = { Color3.fromRGB(214, 170, 110), Color3.fromRGB(196, 150, 96) },
					slatMaterial = Enum.Material.Wood,
					arrow = Color3.fromRGB(255, 220, 90),
				},
				crumble = { color = Color3.fromRGB(220, 80, 70), material = Enum.Material.SmoothPlastic },
				stands = {
					bench = Color3.fromRGB(196, 140, 92),
					riser = Color3.fromRGB(132, 86, 50),
					rail = Color3.fromRGB(240, 190, 70),
				},
			},
		},
	},
}
