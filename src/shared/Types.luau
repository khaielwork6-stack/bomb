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
	Runner = "TT_Runner",
	Bomber = "TT_Bomber",
	SafeRunner = "TT_SafeRunner",
	Lobby = "TT_Lobby",
	Ragdoll = "TT_Ragdoll",
	LineWall = "TT_LineWall",
	Bounds = "TT_Bounds",
	Prop = "TT_Prop",
}

return Types
