--!strict
-- Studio only: static stand-in participants for testing rounds before the real bots land (P2). "dummies <n>" adds n
-- motionless bodies that take part in rounds like anyone else (they get tagged, carry, boom and turn into Bombers);
-- "dummies 0" removes them. Never runs in a live server.

local RunService = game:GetService("RunService")

local AdminService = require(script.Parent.Parent.Services.AdminService)
local Characters = require(script.Parent.Parent.Services.Characters)
local Participants = require(script.Parent.Parent.Services.Participants)

local Dummies = {}

local spawned: { Participants.Participant } = {}

local function folder(): Folder
	local f = workspace:FindFirstChild("Bots") :: Folder?
	if not f then
		f = Instance.new("Folder")
		assert(f, "folder")
		f.Name = "Bots"
		f.Parent = workspace
	end
	return f :: Folder
end

function Dummies.set(n: number): string
	for _, p in ipairs(spawned) do
		if p.model then
			p.model:Destroy()
		end
		Participants.remove(p)
	end
	table.clear(spawned)
	local rng = Random.new()
	for i = 1, n do
		local name = "Dummy" .. i
		local model = Characters.buildBot(name, rng)
		model:PivotTo(CFrame.new(0, 20 + i * 4, 0))
		model.Parent = folder()
		local p = Participants.addBot("D" .. i, name, model, 1, 0)
		local root = p.root
		if root then
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
		end
		Characters.applyGroup(p)
		table.insert(spawned, p)
	end
	return `{n} dummies`
end

function Dummies.start()
	if not RunService:IsStudio() then
		return
	end
	AdminService.register("dummies", function(args)
		return Dummies.set(math.clamp(tonumber(args[1]) or 0, 0, 30))
	end)
end

return Dummies
