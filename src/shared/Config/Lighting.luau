--!strict
-- Lighting presets (Asset Bible §2.5; DECISIONS 2026-10-17: the reference video's bright sunny look wins over the
-- bible's Golden Fuse dusk). `ToyMidday` is the Fireworks Yard's light, applied by builders/MapYardToy (it runs after
-- MapYard, so it replaces MapYard's ClockTime 15.4 Golden Fuse). The night look (LIGHTS OUT) is Config.Modifiers.NIGHT.

local rgb = Color3.fromRGB

return {
	ToyMidday = {
		Lighting = {
			ClockTime = 13.6,
			GeographicLatitude = 30,
			Brightness = 2.6,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
			OutdoorAmbient = rgb(150, 160, 190),
			Ambient = rgb(110, 116, 140),
			ExposureCompensation = 0,
		},
		Atmosphere = {
			Density = 0.22,
			Offset = 0.1,
			Color = rgb(196, 222, 255),
			Decay = rgb(120, 170, 230),
			Glare = 0.1,
			Haze = 0.6,
		},
		ColorCorrection = {
			Saturation = 0.22,
			Contrast = 0.08,
			TintColor = Color3.new(1, 1, 1),
			Brightness = 0.02,
		},
		Bloom = {
			Intensity = 0.35,
			Threshold = 1.6,
			Size = 24,
		},
	},
}
