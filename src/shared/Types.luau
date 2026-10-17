--!strict
-- Shared enums/strings used as attribute values. GDD §21.4.

local Types = {}

Types.Role = {
	None = "None",
	Runner = "Runner",
	Bomber = "Bomber",
}

Types.State = {
	Lobby = "Lobby",
	Active = "Active",
	Safe = "Safe",
	Downed = "Downed",
	Tumbled = "Tumbled",
	Spectator = "Spectator",
	AFK = "AFK",
}

Types.Phase = {
	Boot = "BOOT",
	Lobby = "LOBBY",
	Vote = "VOTE",
	Filling = "FILLING",
	TransitionIn = "TRANSITION_IN",
	Intro = "MATCH_INTRO",
	Crossing = "CROSSING",
	MatchEnd = "MATCH_END",
	TransitionOut = "TRANSITION_OUT",
}

Types.Sub = {
	None = "NONE",
	GetReady = "GET_READY",
	LeadPick = "LEAD_PICK",
	BraveOrBail = "BRAVE_OR_BAIL",
	Reveal = "LINEUP_REVEAL",
	BraveRun = "BRAVE_RUN",
	Run = "RUN",
	Resolve = "RESOLVE",
	LastStandIntro = "LAST_STAND_INTRO",
	Countdown = "COUNTDOWN", -- 3-2-1 before the main run after a Brave run
}

Types.Collision = {
	Runner = "FV_Runner",
	Bomber = "FV_Bomber",
	SafeRunner = "FV_SafeRunner",
	Lobby = "FV_Lobby",
	Ragdoll = "FV_Ragdoll",
	LineWall = "FV_LineWall",
	Bounds = "FV_Bounds",
	Prop = "FV_Prop",
}

return Types
