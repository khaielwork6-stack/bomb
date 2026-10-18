# Requests to the partner (server / gameplay) — from the `fallenbomb` art + UI branch
The UI side builds every screen and piece of art; these are the server hooks the screens need. Each lists what the
client already does and the smallest server change that makes it real. Tick when done.

| # | Feature | What the client will do | What the server needs | Status |
|---|---|---|---|---|
| 1 | Map vote ("NEXT MAP" card) | **Built** (`MapVoteController`): the card in intermission with thumbnails, live counts, "Click or Press 1/2" | A vote phase in intermission, `Config.Maps` with 2+ maps; `GameState` attributes `VoteOptions` (JSON array of map keys), `VoteCounts` (JSON `{ [key] = n }`), `VoteEndsAt` (server `workspace:GetServerTimeNow()`); a `VoteMap` C→S remote with the map key. Only useful once a second map exists | open |
| 2 | Spin wheel | **Built** (`WheelController`): segments from `Config.Wheel.SEGMENTS`, spin animation, ODDS, +1 / +5 spins, free spin countdown. Opened by the lobby wheel's prompt (`FV_Open = "Wheel"`) | `Config.Wheel` is in (PROPOSED values). Needs: `wheel = { spins, freeIn }` in the Progress snapshot (`freeIn` = seconds until the next free spin at snapshot time; `spins` counts the free one), a `Spin` C→S remote (no payload) that rolls by weight on the server and replies `Reward { kind = "Wheel", segment = i }` (1-based index into SEGMENTS) then pays it; the Spin1 / Spin5 developer products via `StoreAction { kind = "BuyProduct", product = "Spin1" }`. **Owner decides rewards / pricing** | open |
| 3 | Crate stands in the lobby | 3D crate stands with a billboard (name, price, odds), the R / F (x1 / x5) prompt and the opening sequence | Nothing new for x1 (StoreAction OpenCrate exists). x5 needs an "open 5" action (one request, 5 rolls, the -20 % price) | open |
| 4 | AFK toggle | **Built** (`LobbyController`, key K): sets the player attribute `AfkWish` and fires `SetAfk(on: boolean)` if that remote exists | A `SetAfk` C→S remote; AFK players are skipped when a round fills (stay in the lobby) | open |
| 5 | Spectate button | A left-dock camera button that cycles live players | Nothing (client camera) unless spectating must be blocked for some players | — |
| 6 | Saved settings on join | Settings screen applies saved values | Send the saved settings back on join (e.g. in the first Progress snapshot) so `Settings.apply` runs | open |
| 7 | Level-up firework others see | A firework over the player's head | Broadcast level-ups (a `LevelUp` kind on ActionFx / RoundFx with the player) | open |
| 8 | Emotes | Emote wheel + the 8 clips | `Emote` in StoreService equip slots; optional lobby-only check | open |
| 9 | Lobby spawn | The Depot plaza (`builders/LobbyDepot.luau`) has its kiosk / crate stand / wheel prompts | Spawn players between rounds at the Depot's `Spawn` part (attribute `LobbySpawn`) instead of the yard | open |
