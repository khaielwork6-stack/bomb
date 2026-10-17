--!strict
-- Shared enums/strings used as attribute values. GDD §5, §22.

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

-- Round phases (GDD §5.2). Values are attribute strings on ReplicatedStorage.GameState ("Phase").
Types.Phase = {
	Boot = "BOOT",
	Intermission = "INTERMISSION",
	Intro = "INTRO",
	Ready = "READY",
	Crossing = "CROSSING",
	Resolve = "RESOLVE",
	LastStand = "LAST_STAND",
	Results = "RESULTS",
}

-- Sub-phases ("SubPhase"): the Last Stand's intro beat before its run (GDD §8.2).
Types.Sub = {
	None = "NONE",
	Intro = "INTRO",
	Run = "RUN",
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
