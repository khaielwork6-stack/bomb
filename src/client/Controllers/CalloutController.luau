--!strict
-- Callouts on screen (GDD §11.1): every moment the server spots becomes its title word (Assets.Title, baked 3D art)
-- through the one voice in the middle of the screen (UI/Announcer) — never a stack. Config.Callouts.List says which
-- word, how important it is (a DOUBLE BOOM! replaces the BOOM! it follows) and which moments say nothing in the centre
-- (PASS! is too frequent; the floating "+N" tag rewards it). A CHAIN arriving while another word is up rides on that
-- word's plate ("×4") instead of stacking. The payout shows as the "+N" tag and the gems flying home, not a text row.
-- Implements: F-CALL-01 (presentation), DECISIONS 2026-10-18 (one voice at a time).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Announcer = require(script.Parent.Parent.UI.Announcer)
local FxController = require(script.Parent.FxController)

local CC = Config.Callouts

local CalloutController = {}

function CalloutController.show(key: string, n: number?)
	local def = CC.List[key]
	if not def or not def.title then
		return
	end
	if key == "Chain" then
		local label = "×" .. tostring(n or 0)
		-- ride on whatever is up (DEFUSED!, BOOM!…) rather than taking the slot
		if Announcer.attach(label) then
			return
		end
		Announcer.say({ key = def.title, priority = def.priority, sub = label, merge = false })
		return
	end
	local shown = Announcer.say({
		key = def.title,
		tier = if def.moment then "Moment" else "Callout",
		priority = def.priority,
	})
	if shown and (def.priority or 0) >= 2.6 then
		FxController.shake(0.18)
	end
end

function CalloutController.start()
	Net.listen("Callout", function(p)
		if type(p) == "table" and type(p.key) == "string" then
			CalloutController.show(p.key, if type(p.n) == "number" then p.n else nil)
		end
	end)
end

return CalloutController
