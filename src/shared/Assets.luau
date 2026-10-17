--!strict
-- Every asset reference goes through this table (Asset Bible §10.5): code uses keys, never raw ids.
-- src: R = Roblox official, PSE = ProSoundEffects, APM = APMOfficial, C = verified community, BI = built-in.
-- P0: only what the transferred movement uses (from Chase Game). The FUSE VALLEY sound stacks (Asset Bible §9) and
-- the bomb's assets are added as their phases land.

type Sound = {
	id: string,
	volume: number,
	pitch: { number }?,
	looped: boolean?,
	src: string,
	alt: { string }?,
	region: { number }?, -- play only this slice of the file (seconds)
}

local function s(id: number | string, volume: number, src: string, extra: { [string]: any }?): Sound
	local entry: any = {
		id = if type(id) == "number" then "rbxassetid://" .. tostring(id) else id,
		volume = volume,
		src = src,
	}
	if extra then
		for k, v in pairs(extra) do
			entry[k] = v
		end
	end
	return entry
end

local Assets = {}

Assets.SFX = {
	-- Movement (Chase Game's tuned set; replaced by designed stacks in the P3 audio pass, Asset Bible §9)
	Dash = s(9126229255, 0.7, "PSE", { alt = { "rbxassetid://9114157695" } }),
	HardStop = s(9118740493, 0.7, "PSE"),
	Slide = s(114100466629000, 0.55, "C", { alt = { "rbxassetid://105544173943722" } }),
	Land = s("rbxasset://sounds/action_jump_land.mp3", 0.6, "BI"),
	-- Footsteps: four soft single-hit steps, one picked at random per footfall (FootstepController sets the pace).
	Footstep1 = s(123224557798023, 0.5, "C"),
	Footstep2 = s(131412978408311, 0.42, "C"),
	Footstep3 = s(114768473003662, 0.45, "C"),
	Footstep4 = s(91882016473062, 0.7, "C"),
}

-- Animations (tools/anim → published to the group; GDD §23.4: same group, so these ids work here).
Assets.Anim = {
	-- Techniques. Side dashes / backward hop keep facing ahead (omnimovement).
	Dash = "rbxassetid://75704029009727",
	DashLeft = "rbxassetid://135292503614941",
	DashRight = "rbxassetid://86994402870442",
	DashBack = "rbxassetid://110857346305282",
	Slide = "rbxassetid://97050214215297",
	HardStop = "rbxassetid://78047444691420",
	Land = "rbxassetid://94922193663467",
	-- Locomotion layer (Shared/Locomotion): Idle, one Run cycle for every speed, Brake, Fall, strafes, Walk (the
	-- backpedal plays it reversed).
	Idle = "rbxassetid://114189129096906",
	Run = "rbxassetid://75779803985231",
	Jog = "rbxassetid://75779803985231",
	Sprint = "rbxassetid://75779803985231",
	Brake = "rbxassetid://93549571432720",
	Fall = "rbxassetid://94527633937528",
	StrafeLeft = "rbxassetid://86125662963794",
	StrafeRight = "rbxassetid://130974800371567",
	Walk = "rbxassetid://77433291886179",
	-- The giant's walk set (Locomotion "Titan" variant), kept for the MEGA BOMBER (GDD §16, P6).
	TitanIdle = "rbxassetid://98326586787465",
	TitanWalk = "rbxassetid://90675009643945",
}

-- Premium painted icons (the Skin kit's Skin.icon). FUSE VALLEY's own set (Asset Bible §6.4) lands with the P5 store.
Assets.Icon = {} :: { [string]: string }

return Assets
