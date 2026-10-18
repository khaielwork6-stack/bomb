--!strict
-- Play registered sounds (Assets.SFX keys) globally or at a world position. Pooled per key for UI sounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Assets = require(ReplicatedStorage.Shared.Assets)

local Sfx = {}

local group: SoundGroup? = nil
Sfx.volume = 0.9 -- settings SFX volume (0..1)

local function getGroup(): SoundGroup
	if group and group.Parent then
		return group
	end
	local g = Instance.new("SoundGroup")
	g.Name = "FV_SFX"
	g.Volume = Sfx.volume
	g.Parent = SoundService
	group = g
	return g
end

function Sfx.setVolume(v: number)
	Sfx.volume = v
	getGroup().Volume = v
end

local function make(key: string): Sound?
	local def = (Assets.SFX :: any)[key]
	if not def then
		warn("[Sfx] unknown key", key)
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = def.id
	if def.alt and #def.alt > 0 then
		-- another take of the same sound, so a frequent moment never repeats exactly
		local pick = math.random(0, #def.alt)
		if pick > 0 then
			s.SoundId = def.alt[pick]
		end
	end
	s.Volume = def.volume
	s.SoundGroup = getGroup()
	if def.pitch then
		local lo, hi = def.pitch[1], def.pitch[2]
		s.PlaybackSpeed = lo + math.random() * (hi - lo)
	end
	if def.region then
		-- Only this slice of the file (e.g. one clack out of a ratchet burst).
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(def.region[1], def.region[2])
	end
	return s
end

-- Load these sounds now, so the first play is on the beat (countdowns, the wheel).
function Sfx.preload(keys: { string })
	local list = {}
	for _, key in ipairs(keys) do
		local s = make(key)
		if s then
			table.insert(list, s)
		end
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
		for _, s in ipairs(list) do
			s:Destroy()
		end
	end)
end

-- 2D (global) sound.
function Sfx.play(key: string, volumeMult: number?, pitch: number?)
	local s = make(key)
	if not s then
		return
	end
	if volumeMult then
		s.Volume *= volumeMult
	end
	if pitch then
		s.PlaybackSpeed = pitch
	end
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 8)
end

-- 3D sound at a world position.
function Sfx.at(key: string, pos: Vector3, volumeMult: number?, pitch: number?)
	local s = make(key)
	if not s then
		return
	end
	if volumeMult then
		s.Volume *= volumeMult
	end
	if pitch then
		s.PlaybackSpeed = pitch
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	s.RollOffMaxDistance = 120
	s.RollOffMinDistance = 12
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 8)
end

-- A looping sound (fuse hiss, heartbeat, crowd bed): 3D when parent is a part or attachment, 2D otherwise.
-- The caller owns it (stop / Destroy).
function Sfx.loop(key: string, parent: Instance?, volumeMult: number?): Sound?
	local s = make(key)
	if not s then
		return nil
	end
	s.Looped = true
	if volumeMult then
		s.Volume *= volumeMult
	end
	s.RollOffMaxDistance = 90
	s.RollOffMinDistance = 8
	s.Parent = parent or SoundService
	s:Play()
	return s
end

return Sfx
