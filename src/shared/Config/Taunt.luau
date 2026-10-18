--!strict
-- Emoji taunts (the owner, 2026-10-18: T opens emojis that pop over your head with a funny sound that matches). The
-- server relays a pick to everyone (Net "Taunt" → "TauntFx"); every client shows the emoji over that player and plays
-- its sound there. Art: art/icons/set_emoji.py (Assets.Icon.Emoji<Key>); sounds: art/audio/make_taunts.py
-- (Assets.SFX.Taunt<Key>). Seconds and studs. [TUNE]

return {
	ORDER = { "Laugh", "Cool", "Angry", "Cry", "Love", "Shock", "Silly", "Skull" }, -- the wheel, clockwise from the top
	COOLDOWN = 2.5, -- seconds between one player's taunts (the server enforces it)
	SHOW_TIME = 2.2, -- how long the emoji stays up
	SIZE = 5, -- the emoji's size over the head (studs)
	HEIGHT = 4.2, -- how far above the head it floats
	MAX_DISTANCE = 140, -- beyond this the emoji isn't drawn
	SOUND_VOLUME = 0.9, -- × the sound's own volume
}
