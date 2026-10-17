--!strict
-- The Last Stand's presentation (GDD §8.2, Asset Bible §2.5 "Spotlight" preset): the world dims to 35 %, a warm
-- spotlight locks onto the last Runner and follows them, a rim light warms the Bombers' line; a win snaps the world
-- back to full light under a firework volley (the loss is the boom itself). Everything here is client-side
-- presentation and restores itself when the round moves on.
-- Implements: F-LAST-01, F-LAST-04 (light + volley beats).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Theme = require(script.Parent.Parent.UI.Theme)
local FxController = require(script.Parent.FxController)

local new = Theme.new
local Ph = Types.Phase

local LastStandController = {}

local DIM = 0.35 -- the world's brightness during the Last Stand

local active = false
local saved: { Brightness: number, ExposureCompensation: number }? = nil
local correction: ColorCorrectionEffect? = nil
local spotPart: Part? = nil
local follow: RBXScriptConnection? = nil

local function tween(obj: Instance, time: number, props: { [string]: any })
	TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), props):Play()
end

local function begin(runnerId: string)
	if active then
		return
	end
	active = true
	saved = { Brightness = Lighting.Brightness, ExposureCompensation = Lighting.ExposureCompensation }
	local cc = new("ColorCorrectionEffect", { Name = "FV_LastStand", Saturation = 0, Parent = Lighting })
	correction = cc
	tween(
		Lighting,
		0.8,
		{ Brightness = Lighting.Brightness * DIM, ExposureCompensation = Lighting.ExposureCompensation - 0.9 }
	)
	tween(cc, 0.8, { Saturation = -0.25, Contrast = 0.12 })
	-- The spotlight: a warm cone from above, following the Runner every frame.
	local part = new("Part", {
		Name = "FV_Spotlight",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one * 0.2,
		Parent = workspace,
	})
	spotPart = part
	new("SpotLight", {
		Face = Enum.NormalId.Bottom,
		Angle = 38,
		Range = 40,
		Brightness = 9,
		Color = Color3.fromHex("#FFD9A8"),
		Shadows = true,
		Parent = part,
	})
	follow = RunService.RenderStepped:Connect(function()
		local _, model = ClientState.byId(runnerId)
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			part.CFrame = CFrame.new(root.Position + Vector3.new(0, 22, 0))
		end
	end)
end

local function finish(win: boolean)
	if not active then
		return
	end
	active = false
	if follow then
		follow:Disconnect()
		follow = nil
	end
	if spotPart then
		spotPart:Destroy()
		spotPart = nil
	end
	local s = saved
	if s then
		tween(
			Lighting,
			if win then 0.25 else 1.2,
			{ Brightness = s.Brightness, ExposureCompensation = s.ExposureCompensation }
		)
	end
	local cc = correction
	if cc then
		tween(cc, if win then 0.25 else 1.2, { Saturation = 0, Contrast = 0 })
		task.delay(1.3, function()
			cc:Destroy()
		end)
		correction = nil
	end
end

-- The victory volley (F-LAST-04): firework bursts above the field around the winner.
local function volley(at: Vector3)
	for i = 1, 7 do
		task.delay(i * 0.18, function()
			local a = i / 7 * math.pi * 2
			local pos = at + Vector3.new(math.cos(a) * 14, 20 + (i % 3) * 5, math.sin(a) * 14)
			FxController.boom(pos, 0.7)
		end)
	end
end

function LastStandController.start()
	local gs = ReplicatedStorage:WaitForChild("GameState") :: Configuration
	gs:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = ClientState.phase()
		if phase == Ph.LastStand then
			local id = gs:GetAttribute("LastStandId")
			if type(id) == "string" and id ~= "" then
				begin(id)
			end
		elseif active and (phase == Ph.Results or phase == Ph.Intermission) then
			local win = gs:GetAttribute("Outcome") == "LastStand"
			local id = gs:GetAttribute("LastStandId")
			local _, model = ClientState.byId(if type(id) == "string" then id else "")
			local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
			finish(win)
			if win and root then
				volley(root.Position)
			end
		end
	end)
	-- A theme cue for the reveal (the full sound design is the P3 audio pass).
	Net.listen("RoundFx", function(p)
		if type(p) == "table" and p.kind == "LastStand" then
			FxController.shake(0.12)
		end
	end)
end

return LastStandController
