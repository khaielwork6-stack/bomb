--!strict
-- Sound design (GDD §10.1 escalation ladder, Asset Bible §9): music crossfades by phase; while you carry, the music is
-- muffled and pulled down, a heartbeat syncs in and your own tick paces 2 → 4 → 10 Hz with rising pitch; every
-- moment plays as a layered stack (stick = clamp, pass = whoosh + clamp, boom = hit + body + debris, defuse = snuff +
-- chime, clutch = sting), plus the klaxon, the field detonation, the Last Stand drumroll + crowd and the result
-- stings. Every sound is a licensed library asset registered in Shared/Assets.
-- Implements: F-FEEL-01 (audio layers), F-FEEL-03 (audio beats), F-LAST-01/02 (drumroll, crowd).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.Settings)
local Sfx = require(script.Parent.Parent.Sfx)

local B = Config.Bomb
local Ph = Types.Phase
local player = Players.LocalPlayer

local AudioController = {}

local musicGroup: SoundGroup
local muffle: EqualizerSoundEffect
local tracks: { [string]: Sound } = {}
local current: string? = nil
local heartbeat: Sound? = nil
local whine: Sound? = nil
local crowd: Sound? = nil
local tickAcc = 0
local tockNext = false
-- The in-house tick set is used once all four files have ids (Assets: "" = not uploaded yet).
local inHouseTicks = true
for _, k in ipairs({ "BombTickA", "BombTickB", "BombTickHotA", "BombTickHotB" }) do
	local def = (Assets.SFX :: any)[k]
	if not def or def.id == "" then
		inHouseTicks = false
	end
end

local MUSIC_VOLUME = 0.8

-- ── Music ───────────────────────────────────────────────────────────────────────────────────────────────────────
local function track(key: string): Sound?
	local def = (Assets.Music :: any)[key]
	if not def then
		return nil
	end
	local s = tracks[key]
	if not s then
		local snd = Instance.new("Sound")
		snd.Name = "Music_" .. key
		snd.SoundId = def.id
		snd.Volume = 0
		snd.Looped = def.looped == true
		snd.SoundGroup = musicGroup
		snd.Parent = SoundService
		tracks[key] = snd
		s = snd
	end
	return s
end

local function playMusic(key: string?)
	if key == current then
		return
	end
	local old = current and tracks[current]
	if old then
		local o = old
		TweenService:Create(o, TweenInfo.new(0.8), { Volume = 0 }):Play()
		task.delay(0.85, function()
			if current ~= nil and tracks[current] ~= o then
				o:Stop()
			end
		end)
	end
	current = key
	if key then
		local s = track(key)
		local def = (Assets.Music :: any)[key]
		if s and def then
			s.TimePosition = 0
			s:Play()
			TweenService:Create(s, TweenInfo.new(0.8), { Volume = def.volume }):Play()
		end
	end
end

local function musicFor(phase: string): string?
	if phase == Ph.Intermission or phase == Ph.Boot then
		return "Lobby"
	elseif phase == Ph.LastStand then
		return "LastStand"
	elseif phase == Ph.Results then
		return "Results"
	end
	return "Round"
end

-- ── The carrier layer (every frame) ─────────────────────────────────────────────────────────────────────────────
local function step(dt: number)
	local explodeAt = player:GetAttribute("BombExplodeAt")
	local masked = player:GetAttribute("BombMasked") == true -- READ THE FACE: no time while LIT (F-MOD-02)
	local carrying = (type(explodeAt) == "number" or masked) and player:GetAttribute("BombId") ~= nil
	-- Music: muffled and pulled down while you carry (the drums "cut out", GDD §10.1).
	local wantHigh = if carrying then -22 else 0
	muffle.HighGain += (wantHigh - muffle.HighGain) * math.min(1, dt * 8)
	muffle.MidGain += ((if carrying then -8 else 0) - muffle.MidGain) * math.min(1, dt * 8)
	local base = MUSIC_VOLUME * ((Settings.get("musicVolume") or 70) / 70)
	musicGroup.Volume += ((if carrying then base * 0.55 else base) - musicGroup.Volume) * math.min(1, dt * 6)
	local wantWhine = carrying
		and type(explodeAt) == "number"
		and explodeAt - workspace:GetServerTimeNow() <= B.STAGE_CRITICAL
	if whine and not wantWhine then
		whine:Destroy()
		whine = nil
	end
	if not carrying then
		if heartbeat then
			heartbeat:Destroy()
			heartbeat = nil
		end
		tickAcc = 0
		return
	end
	local remaining = if type(explodeAt) == "number" then explodeAt - workspace:GetServerTimeNow() else math.huge
	local stage = if remaining <= B.STAGE_CRITICAL then 3 elseif remaining <= B.STAGE_HOT then 2 else 1
	if not heartbeat then
		heartbeat = Sfx.loop("Heartbeat", nil)
	end
	local hb = heartbeat
	if hb then
		hb.PlaybackSpeed = ({ 1.05, 1.35, 1.75 })[stage]
	end
	-- Your own tick, paced by stage (§7.2: 2 / 4 / 10 Hz): the in-house escapement alternates tick / tock and turns
	-- to its brighter, tighter pair at CRITICAL; until those files are uploaded, the fallback tick is pitched up.
	if stage == 3 and not whine then
		whine = Sfx.loop("BombCritical", nil)
	end
	if whine then
		whine.PlaybackSpeed = 1 + math.clamp((B.STAGE_CRITICAL - remaining) / B.STAGE_CRITICAL, 0, 1) * 0.5
	end
	local hz = ({ 2, 4, 10 })[stage]
	tickAcc += dt
	if tickAcc >= 1 / hz then
		tickAcc = 0
		tockNext = not tockNext
		if inHouseTicks then
			local key = (if stage == 3 then "BombTickHot" else "BombTick") .. (if tockNext then "B" else "A")
			Sfx.play(key, if stage == 3 then 0.85 else 1, ({ 1.0, 1.04, 1.0 })[stage])
		else
			Sfx.play("BombTick", if stage == 3 then 0.8 else 1, ({ 1.0, 1.12, 1.3 })[stage])
		end
	end
end

-- ── Moments ─────────────────────────────────────────────────────────────────────────────────────────────────────
local function rootOf(id: string?): BasePart?
	if not id then
		return nil
	end
	local _, model = ClientState.byId(id)
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onBomb(p: any)
	if type(p) ~= "table" then
		return
	end
	local mine = p.who == ClientState.myId()
	if p.kind == "Stick" then -- the clamp itself plays on the slap's contact frame (SlapController); the fuse catches
		local r = rootOf(p.who)
		if mine then
			Sfx.play("BombIgnite")
		elseif r then
			Sfx.at("BombIgnite", r.Position, 0.8)
		end
	elseif p.kind == "Pass" then
		local from, to = rootOf(p.from), rootOf(p.who)
		if from then
			Sfx.at("PassWhoosh", from.Position)
		end
		-- the clamp bites as the bomb lands (D-PASS-02: after the flight)
		task.delay(Config.Feel.PASS_TIME, function()
			if mine then
				Sfx.play("BombClamp", 1.2, 1.25)
			elseif to then
				Sfx.at("BombClamp", to.Position, 1, 1.25)
			end
		end)
	elseif p.kind == "Boom" and typeof(p.pos) == "Vector3" then
		local pos = p.pos :: Vector3
		if mine then
			Sfx.play("BoomHit", 1.2)
			Sfx.play("BoomBody", 1.1, 0.95)
			Sfx.play("BoomDebris", 1, 1)
		else
			local pitch = 0.92 + math.random() * 0.16
			local cam = workspace.CurrentCamera
			if cam ~= nil and (cam.CFrame.Position - pos).Magnitude > 40 then
				Sfx.at("BoomFar", pos, 1, pitch) -- beyond 40 studs only the low tail carries (AB §9.2)
			else
				Sfx.at("BoomHit", pos, 1, pitch)
				Sfx.at("BoomBody", pos, 1, pitch)
				Sfx.at("BoomDebris", pos, 1, pitch)
			end
		end
	elseif p.kind == "Defuse" and typeof(p.pos) == "Vector3" then
		-- the snuff, the clamp's latch, the bomb clunking to the floor, then the chime (AB §3.3 Defuse)
		if mine then
			Sfx.play("FuseSnuff")
			Sfx.play("Defuse", 0.6)
			task.delay(0.12, function()
				Sfx.play("BombRelease")
			end)
			task.delay(0.35, function()
				Sfx.play("BombDrop")
			end)
			Sfx.play("Safe")
			if p.clutch then
				Sfx.play("ClutchChoir")
			end
		else
			Sfx.at("FuseSnuff", p.pos)
			task.delay(0.35, function()
				Sfx.at("BombDrop", p.pos, 0.8)
			end)
			Sfx.at("Safe", p.pos, 0.7)
		end
	end
end

function AudioController.start()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "FV_Music"
	musicGroup.Volume = MUSIC_VOLUME
	musicGroup.Parent = SoundService
	muffle = Instance.new("EqualizerSoundEffect")
	muffle.LowGain = 0
	muffle.MidGain = 0
	muffle.HighGain = 0
	muffle.Parent = musicGroup
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	local function onPhase()
		local phase = ClientState.phase()
		playMusic(musicFor(phase))
		if phase ~= Ph.LastStand and crowd then
			local c = crowd
			crowd = nil
			TweenService:Create(c, TweenInfo.new(1), { Volume = 0 }):Play()
			task.delay(1.05, function()
				c:Destroy()
			end)
		end
	end
	gs:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	onPhase()
	RunService.RenderStepped:Connect(step)
	Net.listen("BombFx", onBomb)
	Net.listen("FieldFx", function(p)
		if type(p) ~= "table" then
			return
		end
		if p.kind == "Warn" then
			Sfx.play("Klaxon")
		elseif p.kind == "Detonate" then
			Sfx.play("FieldDetonate")
			Sfx.play("BoomBody", 0.9, 0.8)
		end
	end)
	Net.listen("RoundFx", function(p)
		if type(p) ~= "table" then
			return
		end
		if p.kind == "Intro" then
			Sfx.play("StingerBombers")
		elseif p.kind == "LastStand" then
			Sfx.play("DrumRoll")
			crowd = Sfx.loop("CrowdChant", nil)
		elseif p.kind == "Results" then
			local won = false
			for _, id in ipairs(if type(p.winners) == "table" then p.winners else {}) do
				if id == ClientState.myId() then
					won = true
				end
			end
			Sfx.play(if won then "WinSting" else "LoseSting")
			if p.outcome == "LastStand" then
				Sfx.play("CrowdCheer")
			elseif p.outcome == "Bombers" and ClientState.phase() == Ph.Results then
				Sfx.play("StingerBombersWin", 0.8)
				Sfx.play("CrowdGroan", 0.7)
			end
		end
	end)
end

return AudioController
