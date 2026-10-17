# DECISIONS — FUSE VALLEY
Log every ambiguity resolved during the build: date, question, decision, GDD section. Locked design decisions are in GDD §2.

| Date | Question | Decision | GDD |
|---|---|---|---|
| 2026-10-17 | The 10 open questions before the GDD | The user said "go" → the recommended picks were locked (GDD §2, D1–D11) | §2 |
| 2026-10-17 | Where do Chase's Combat dive/history numbers go? | `Config.Movement` (the dive stays in MovementCore, unused by FUSE VALLEY; `HISTORY_SECONDS` raised to 6.5 for the moment replay) | §9, §10.5 |
| 2026-10-17 | Lobby techniques | Kept Chase's rule: only Dash outside a round | §9.4 |
| 2026-10-17 | P0 test flow without a round system | A temporary `Sandbox` service makes everyone an active Runner on the Meadow start strip; it gets deleted in P1 | §23.3 |
| 2026-10-17 | Where do players wait between rounds before the lobby exists? | On the start Safe Strip (`RoundService.resetToLobby`) until "The Depot" lobby lands in P6 | §19 |
| 2026-10-17 | Separate FieldFuseService? | Folded into RoundService (it's the crossing timer; one owner for crossing state). FieldFx remote as specified | §22.3 |
| 2026-10-17 | Can a Bomber carrying a locked (revenge) bomb still tag? | Yes: the GDD doesn't forbid it, it's readable, and it keeps Bombers dangerous while they tick | §7.5 |
| 2026-10-17 | P1 client visuals use engine parts + engine particle textures | Internal grey-box only (never shipped); the Blender hero bomb and in-house VFX textures replace them in P3 under the Quality Bar | AB §1.3, §3 |
| 2026-10-17 | Studio play-tests and the new place's DataStore | Studio API access is off for the new place, so profiles stay in memory during tests. **Human: Game Settings → Security → enable Studio Access to API Services before P4** | §24.3 || 2026-10-17 | Field Fuse lengths on maps of other sizes | The §6.2 lengths are for a 140-stud field (`FUSE_REF_LENGTH`); RoundService scales them by the field's length (the temporary 198-stud Meadow gets ≈1.4×), so every map keeps the same pressure | §6.2 |
| 2026-10-17 | Bots and the Field Fuse | A Runner bot only waits for a gap while the remaining fuse still covers the whole run with 25 % slack (otherwise it goes at once) | §18.2 F-BOT-02 |
| 2026-10-17 | Bots look like players? | Kept Chase Game's approach: real avatar looks from AvatarPool (never a real name), generated names, no BOT chip (`SHOW_BOT_TAG = false`) | §18.1 |
| 2026-10-17 | AvatarPool crowd templates | Off (`CROWD_TEMPLATES = 0`): FUSE VALLEY has no stands; the Last Stand crowd is audio only | §8.2 |