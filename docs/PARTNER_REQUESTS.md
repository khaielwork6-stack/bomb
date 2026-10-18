# Requests to the partner (server / gameplay) — from the `fallenbomb` art + UI branch
The UI side builds every screen and piece of art; these are the server hooks the screens need. Each lists what the
client already does and the smallest server change that makes it real. Tick when done.

| # | Feature | What the client will do | What the server needs | Status |
|---|---|---|---|---|
| 1 | Map vote ("NEXT MAP" card) | Shows the card in intermission with map thumbnails, live vote counts + voter avatars, "Click or Press 1/2" | A vote phase in intermission, `Config.Maps` with 2+ maps, a `VoteMap` C→S remote, vote counts replicated (attributes on `ReplicatedStorage.GameState`). Only useful once a second map exists | open |
| 2 | Spin wheel | The wheel screen (segments, spin animation, ODDS, +1 / +5 spins, free spin timer) | Rewards table + odds in `Config`, a free-spin timer in the profile, a `Spin` C→S remote that rolls on the server and replies with the segment; spin products if paid. **Owner decides rewards / pricing** | open |
| 3 | Crate stands in the lobby | 3D crate stands with a billboard (name, price, odds), the R / F (x1 / x5) prompt and the opening sequence | Nothing new for x1 (StoreAction OpenCrate exists). x5 needs an "open 5" action (one request, 5 rolls, the -20 % price) | open |
| 4 | AFK toggle | A left-dock toggle (ON / OFF) | An `AFK` C→S remote; AFK players are skipped when a round fills (stay in the lobby) | open |
| 5 | Spectate button | A left-dock camera button that cycles live players | Nothing (client camera) unless spectating must be blocked for some players | — |
| 6 | Saved settings on join | Settings screen applies saved values | Send the saved settings back on join (e.g. in the first Progress snapshot) so `Settings.apply` runs | open |
| 7 | Level-up firework others see | A firework over the player's head | Broadcast level-ups (a `LevelUp` kind on ActionFx / RoundFx with the player) | open |
| 8 | Emotes | Emote wheel + the 8 clips | `Emote` in StoreService equip slots; optional lobby-only check | open |
