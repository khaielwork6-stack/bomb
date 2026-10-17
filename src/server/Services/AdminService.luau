--!strict
-- Debug commands (GDD §23.2). Studio: a BindableFunction "CG_Debug" in ServerScriptService lets tools drive the
-- *running* services (the command bar runs in a separate VM, so requiring modules there would duplicate state).
-- Live servers: admins (Config.Debug.ADMIN_IDS) can use the same commands through the "Admin" remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local AdminService = {}

type Handler = (args: { any }) -> any
local commands: { [string]: Handler } = {}

function AdminService.register(name: string, fn: Handler)
	commands[string.lower(name)] = fn
end

function AdminService.run(name: string, args: { any }?): any
	local fn = commands[string.lower(name)]
	if not fn then
		return "unknown command: " .. name
	end
	local ok, res = pcall(fn, args or {})
	if not ok then
		return "error: " .. tostring(res)
	end
	return res
end

function AdminService.list(): { string }
	local out = {}
	for k in pairs(commands) do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

function AdminService.start()
	AdminService.register("help", function()
		return table.concat(AdminService.list(), ", ")
	end)
	if RunService:IsStudio() then
		local bf = Instance.new("BindableFunction")
		bf.Name = "CG_Debug"
		bf.OnInvoke = function(name: string, ...)
			return AdminService.run(name, { ... })
		end
		bf.Parent = ServerScriptService
	end
	Net.on("Admin", function(player, name, args)
		if not table.find(Config.Debug.ADMIN_IDS, player.UserId) and not RunService:IsStudio() then
			return
		end
		if type(name) == "string" then
			print(`[Admin] {player.Name}: {name}`, AdminService.run(name, if type(args) == "table" then args else {}))
		end
	end)
end

return AdminService
