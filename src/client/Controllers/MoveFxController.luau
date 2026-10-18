--!strict
-- Movement presentation (GDD §9, §10.3): the clip, sound and camera beat for every technique. It plays your own moves
-- the instant you press the key (MovementController.Tech) and other players' moves from the server's ActionFx relay.
-- Replaces the movement part of Chase Game's FeedbackController (§23.1). Dust, trails and the rest of the premium
-- feedback layer arrive with the P3 FX pass. Dash and Slide draw the mover's equipped Eq_Trail ribbon for the move
-- (Asset Bible §8.2, Client/VfxCosmetic). Implements: F-MOVE-01, F-FEEL-03 (movement beats), F-STORE-01 (trails).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)
local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)
local PoseController = require(script.Parent.PoseController)
local VfxCosmetic = require(script.Parent.Parent.VfxCosmetic)

local M = Config.Movement
local player = Players.LocalPlayer

local MoveFxController = {}

-- A side dash (A / D) or a backward hop (S) plays its own clip, the body still facing ahead.
local function dashPose(side: string?): string
	if side == "Left" then
		return "DashLeft"
	elseif side == "Right" then
		return "DashRight"
	elseif side == "Back" then
		return "DashBack"
	end
	return "DashLean"
end

local function feetOf(model: Model?): Vector3?
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position - Vector3.new(0, 2.8, 0) else nil
end

local function onLocalTech(kind: string, side: string?)
	local char = player.Character
	if kind == "Dash" then
		PoseController.play(char, dashPose(side))
		Sfx.play("Dash")
		CameraController.punch(4)
		VfxCosmetic.trail(char, player:GetAttribute("Eq_Trail"), M.DASH_TIME)
	elseif kind == "HardStop" then
		PoseController.play(char, "HardStop")
		Sfx.play("HardStop")
	elseif kind == "Slide" then
		PoseController.play(char, "Slide")
		Sfx.play("Slide")
		VfxCosmetic.trail(char, player:GetAttribute("Eq_Trail"), M.SLIDE_TIME)
	elseif kind == "Land" then
		PoseController.play(char, "Land")
		Sfx.play("Land")
	end
end

local function onActionFx(payload: any)
	if type(payload) ~= "table" or type(payload.who) ~= "string" then
		return
	end
	local host, model = ClientState.byId(payload.who)
	if not host or not model or model == player.Character then
		return
	end
	local kind = payload.kind
	local feet = feetOf(model)
	if kind == "Dash" then
		PoseController.play(model, dashPose(payload.side))
		if feet then
			Sfx.at("Dash", feet, 0.8)
		end
		VfxCosmetic.trail(model, host:GetAttribute("Eq_Trail"), M.DASH_TIME)
	elseif kind == "HardStop" or kind == "Slide" then
		PoseController.play(model, kind)
		if feet then
			Sfx.at(kind, feet, 0.8)
		end
		if kind == "Slide" then
			VfxCosmetic.trail(model, host:GetAttribute("Eq_Trail"), M.SLIDE_TIME)
		end
	end
end

function MoveFxController.start()
	MovementController.Tech:Connect(onLocalTech)
	Net.listen("ActionFx", onActionFx)
end

return MoveFxController
