--!strict
-- Shared settings readable by both server and client. Every tunable lives in a submodule here; code never hard-codes
-- numbers (GDD §0, Appendix A). Add a submodule here when its phase lands (Round/Bomb: P1, Bots: P2, Economy…: P4).

local Config = {
	GameName = "FUSE VALLEY", -- D1; change only here (GDD §2)

	Game = require(script.Game),
	Movement = require(script.Movement),
	Round = require(script.Round),
	Bomb = require(script.Bomb),
	Feel = require(script.Feel),
	Mega = require(script.Mega),
	Modifiers = require(script.Modifiers),
	Lobby = require(script.Lobby),
	Loading = require(script.Loading),
	Bots = require(script.Bots),
	Callouts = require(script.Callouts),
	Titles = require(script.Titles),
	Onboarding = require(script.Onboarding),
	Economy = require(script.Economy),
	Daily = require(script.Daily),
	Strings = require(script.Strings),
	Store = require(script.Store),
	Wheel = require(script.Wheel),
	Taunt = require(script.Taunt),
	Mobile = require(script.Mobile),
	Lighting = require(script.Lighting),
	Hype = require(script.Hype),
	Arena = require(script.Arena),
	Maps = require(script.Maps),
	Data = require(script.Data),
	Debug = require(script.Debug),
}

return Config
