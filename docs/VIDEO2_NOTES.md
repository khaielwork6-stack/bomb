# Reference video round 2 (owner, 2026-10-18)

Three new clips of the reference game ("Huss Tackle"-style football tag) and five screenshots. Frames and contact
sheets: `art/ref/video2/` (git-ignored, like `art/ref/video/`). The owner's asks, what the reference does, how it maps
onto FUSE VALLEY, and who builds it.

Key: **CLIENT** = the art/UI side can build it now · **PARTNER** = needs server work first (logged in
`docs/PARTNER_REQUESTS.md`) · **OWNER** = a monetisation / rule call (GDD golden rule 1).

## 1. "Become Lead Catcher" during the map vote → *Become Lead Bomber* (R$)
- **Reference (v1 0:00–0:14):** a red "Become Lead Catcher" button, hotkey **R**, sits under the NEXT MAP card for the whole
  vote.
- **Ours:** under the NEXT MAP card (MapVoteController), a red "BECOME LEAD BOMBER" button (key R) that prompts a
  Robux dev product. Hidden while its product id is 0 (like every product).
- **Who:**
  - **PARTNER:** a `LeadBomber` product in `Config.Store.PRODUCTS`; ProcessReceipt queues the buyer; the next round's
    bomber pick puts them in the starting Bombers (refund / carry-over if the round can't).
  - **OWNER:** price.
  - **CLIENT:** the button, once the product exists.

## 2. The pick camera ("10 … LEAD CATCHER" → crowd sweep → "HERO OR CHICKEN?")
- **Reference (v1 0:15–0:24; v2 0:31–0:36):**
  1. Black letterbox bars and a big countdown number (10, 9, 8…).
  2. The camera is on the Lead Catcher in the middle of the field with "LEAD CATCHER" under the number.
  3. It cuts to a camera roaming over the waiting crowd, with a white viewfinder reticle (four corner brackets) jumping
     between candidates and blue bubbles drifting up.
  4. It snaps close onto the picked player: their body turns a satisfying gold-yellow with a white glow, the name in
     huge red letters (black outline), "HERO OR CHICKEN?" under it, and the countdown continues (4, 3…).
  5. Then a "HERO" tag over their head as the round starts.
  6. A whoosh / tick on each reticle jump and a sting on the lock-on.
- **Ours:** the INTRO phase already picks the starting Bombers server-side and sends `RoundFx {kind="Intro",
  bombers}`.
  - **CLIENT:** a PickController for INTRO: letterbox, countdown, a viewfinder sweep across the Runners in the strip,
    then a lock-on onto each starting Bomber (gold body Highlight + glow, the name in big red, a "BOMBER!" sub-line,
    sting), then back to the player's camera. Same logic as now, only the presentation.
  - **OWNER / PARTNER:** `Config.Round.INTRO` is 4 s. The reference's sequence runs ~8–10 s. To match it 1:1 INTRO
    needs ~8 s (a pacing change: D-PACE-02 trimmed between-crossing time, but this is once per round). The CLIENT
    version fits 4 s until then.

## 3. The pack offer during the pick → *Bomber Pack* (R$)
- **Reference:** while the hero is being chosen and through the first crossing, a "Catcher Pack" card sits bottom-right:
  icon, green R$ 112 button, three lines of contents (Wooden Mallet, Rocket Dive, 50 Gems).
- **Ours:** a "BOMBER PACK" card bottom-right during INTRO and the first crossing for Bombers (a "RUNNER PACK" for
  Runners). Contents from `Config.Store`.
- **Who:**
  - **OWNER:** contents and price.
  - **PARTNER:** the product and its grant.
  - **CLIENT:** the card (hidden while id 0).

## 4. Juke → the screen goes yellow, the crowd roars, it gets intense
- **Reference (v1 ~0:56):**
  - a "JUKE!" callout bottom-centre, "+10" on the body, a yellow lightning-zigzag decal burst on the floor;
  - the screen edge flashes yellow, the crowd cheers, a short slow beat.
- **Ours:** the Dodge callout (`Callout {key="Dodge"}`, sent to the dodging Runner) is our juke.
- **CLIENT:**
  - a golden screen-edge flash + speed lines;
  - a crowd roar (CrowdCheer) that swells with consecutive dodges;
  - a yellow zigzag floor burst under you;
  - "JUKE!" styling for the Dodge callout.
  - Optionally rename Dodge → JUKE (a string) — OWNER.

## 5. Revive (R$) after you die
- **Reference:** a downed player sees a REVIVE tile (heart, key **Q**, R$ 20) bottom-centre.
- **Ours:** there's no death. A boomed Runner tumbles and gets up as a Bomber (F-BOMB-06). A "revive" would mean
  *stay a Runner* (get up as a Runner again).
- **That's a gameplay-rule change (OWNER), then PARTNER** (a `Revive` product + the rule in BombService).
- **CLIENT:** the REVIVE tile (heart icon, Q, price) during the tumble, once it exists.

## 6. Takedown / Double Takedown + the reward flying to your body
- **Reference (v2):**
  - a big orange "TAKEDOWN!" over the action;
  - "+45 Takedown!" floats beside your character;
  - a bottom-centre "DOUBLE TAKEDOWN! +53 ×2 COMBO";
  - the gem counter ticks as gems arrive.
- **Ours:**
  - Tagged / Boom / DoubleBoom callouts already exist (CalloutController), with their XP / Stars.
  - **CLIENT:**
    - restyle to that read: the big word over the field;
    - a "+N Word!" tag that pops beside your own body and floats up;
    - a combo line bottom-centre ("×2 COMBO");
    - the earned Stars fly as little 3D stars from your body into the Stars counter, which ticks up per star.

## 7. Standings between rounds
- **Reference (v3):** after "CROSSING COMPLETE":
  - A STANDINGS banner slides down, with a "ROUND 4 / 6" chip.
  - Rows slide in from the right one after another: rank, avatar, name, "+gained" chip, points. Gold, silver and bronze
    rows for the top 3; the local player's row is outlined in white.
  - Each row's points count up, then the rows re-sort with a smooth slide, with green ▲ / red ▼ arrows for movement.
  - The panel slides away as the next pick starts.
- **Ours:** a round is 8 crossings; there's no multi-round match or points table.
- **PARTNER:** match points (per crossing or per round, per participant), a match length (rounds), and a replicated
  standings payload `{ round, of, rows = { id, points, gained, rank, prevRank } }`.
- **OWNER:** whether FUSE VALLEY gets a multi-round match. Per-crossing standings inside one round would also work.
- **CLIENT:** the StandingsController (all the animation above).

## 8. Emotes (G) and Taunt (T)
- **Reference:** right side, an EMOTES button (laughing face, key G) above a TAUNT button (key T).
- **Ours:**
  - the 8 emote clips are uploaded (Assets.Anim.Emote*);
  - the shop sells emotes;
  - an animation played on your own character replicates to everyone.
- **CLIENT:**
  - the G emote wheel (owned emotes);
  - a T taunt (one quick clip, authored with tools/anim);
  - both buttons on the right edge (and the phone layout);
  - lobby / intermission and Safe Strip only, so they never interrupt a run.
- **PARTNER (nice to have):** an Emote equip slot (request #8) for a "favourite" order.

## Status
- §4 juke intensity: **done** (HypeController.juke, art/vfx/make_juke.py).
- §6 takedown / reward to the body: **done** (HypeController.reward; the callout word stays CalloutController's).
- §2 pick camera: **done** (PickController; fits the current 4 s INTRO, Studio preview FV_PreviewPick).
- §8 emotes + taunt: **done** (EmoteController; tools/anim/Taunt.luau baked offline and published).

## Order of work (CLIENT now)
1. Juke intensity (4).
2. Takedown / reward-to-body (6).
3. Pick camera (2).
4. Emotes / Taunt (8).
5. Card / button shells for 1, 3 and 5, hidden until their products exist.
6. Standings (7) once its payload exists.
