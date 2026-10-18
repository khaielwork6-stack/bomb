--!strict
-- Colour-blind outlines (the Settings toggle "Colour-blind Mode", GDD §21 accessibility): with it on, every Runner and
-- Bomber in a round gets a team outline in a colour-blind-safe pair (blue Runners, orange Bombers — distinct for every
-- common type of colour blindness), so the teams never rely on red vs cyan alone. Off: no outlines at all.
-- One Highlight per character (Roblox draws at most 31 at once; a server is 30 players at most).
-- Implements: F-ACC-02 (colour-blind team outlines).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.Settings)

local OutlineController = {}

local R = Types.Role
local COLOR = {
	[R.Runner] = Color3.fromRGB(40, 120, 255),
	[R.Bomber] = Color3.fromRGB(255, 150, 20),
}
local NAME = "FV_TeamOutline"
local CHECK_EVERY = 0.4 -- seconds between sweeps (roles change a few times a round)

local function sweep()
	local on = Settings.get("colourBlindOutlines") == true
	for _, e in ipairs(ClientState.participants()) do
		local model = e.model
		if model then
			local role = e.host:GetAttribute("Role")
			local color = on and COLOR[role] or nil
			local h = model:FindFirstChild(NAME) :: Highlight?
			if color then
				if not h then
					local nh = Instance.new("Highlight")
					nh.Name = NAME
					nh.FillTransparency = 1
					nh.OutlineTransparency = 0
					nh.DepthMode = Enum.HighlightDepthMode.Occluded
					nh.Parent = model
					h = nh
				end
				(h :: Highlight).OutlineColor = color
			elseif h then
				h:Destroy()
			end
		end
	end
end

function OutlineController.start()
	Settings.Changed:Connect(function(key)
		if key == "colourBlindOutlines" then
			sweep()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			if Players.LocalPlayer.Parent then
				pcall(sweep)
			end
		end
	end)
end

return OutlineController
